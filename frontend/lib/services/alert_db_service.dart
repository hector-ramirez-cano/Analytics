import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/debouncer.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/extensions/queue.dart';
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/alerts/alert_event.dart';
import 'package:network_analytics/models/alerts/alert_filters.dart';
import 'package:network_analytics/models/alerts/alert_severity.dart';
import 'package:network_analytics/models/alerts/alert_table_page.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:oxidized/oxidized.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'alert_db_service.g.dart';

Logger alertServiceLogger = Logger(filter: ConfigFilter.fromConfig('debug/enable_alert_service_logging', false));
  

String dateString(DateTime time) {
  return '${time.year}-${time.month}-${time.day}:${time.hour}:${time.minute}.${time.second}';
}

/// Creates a [DateTime] for .now(), and sets both the start of the [DateTimeRange] to it, truncating anything after days
/// This is used so the LogTable defaults to a range of 0 seconds at this moment,
/// but doesn't deviate if it's recreated more than once
DateTimeRange _nowEmptyDateTimeRange() {
  final datetime = DateTime.now();

  // truncate seconds and millis, and set them for both start and end
  return DateTimeRange(
    start: DateTime(datetime.year, datetime.month, datetime.day),
    end  : DateTime(datetime.year, datetime.month, datetime.day),
  );
}

final alertWsProvider = Provider<(WebSocketChannel, Stream, Completer)>((ref) {
  try {
    final endpoint = Uri.parse(AppConfig.getOrDefault('ws/alerts_ws_endpoint'));
    final channel = WebSocketChannel.connect(endpoint);
    final stream = channel.stream.asBroadcastStream();
    final connected = Completer<void>();

    alertServiceLogger.i('Attempting to start websocket on endpoint=$endpoint');
    // TODO: Handle onError
    channel.ready.then((_) {
      alertServiceLogger.d('Websocket channel ready');
      connected.complete();
    },
      onError: (err, st) => {
        alertServiceLogger.e('Websocket failed to connect with error = $err')
      }
    );

    ref.onDispose(() {
      channel.sink.close();
    });
  return (channel, stream, connected);
  } catch (e) {
    alertServiceLogger.e(e.toString());
    rethrow;
  }
});

@riverpod
class AlertFilter extends _$AlertFilter {
  @override
  AlertFilters build() {
    return AlertFilters.empty(_nowEmptyDateTimeRange());
  }

  void setFilters(AlertFilters filters) {
    state = filters;
  }
}


@Riverpod(keepAlive: true)
class AlertDbService extends _$AlertDbService {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig('debug/enable_syslog_service_logging', false));
  late WebSocketChannel _channel;
  late Stream _stream;
  late Completer _wsCompleter;
  late StreamSubscription _streamSubscription;
  final Queue<AlertEvent> _pending = Queue();
  Timer? _batchTimer;

  static const Duration _debounceDuration = Duration(milliseconds: 1000);
  final Debouncer _msgDebouncer      = Debouncer(delay: _debounceDuration);
  final Debouncer _ackActorDebouncer = Debouncer(delay: _debounceDuration);
  final Debouncer _targetIdDebouncer = Debouncer(delay: _debounceDuration);
  final Debouncer _alertIdDebouncer  = Debouncer(delay: _debounceDuration);
  
  Semaphore pageReady = Semaphore();
  Semaphore serviceReady = Semaphore();
  int messageCount = 0;

  @override
  Future<int> build() async {
    alertServiceLogger.d('Recreating AlertTablePage notifier!');
    final filters = ref.watch(alertFilterProvider);
    final ws = ref.watch(alertWsProvider);
    _channel = ws.$1;
    _stream = ws.$2;
    _wsCompleter = ws.$3;

    serviceReady.reset();
    _pending.clear();

    final count = await _getRowCount(_channel, _stream, filters);

    if (count.isErr()) {
      throw(count.err().expect("[ERROR]Error result doesn't contain an error message"), StackTrace.current);
    } else {
      messageCount = count.unwrap();
    }

    ref.onDispose(() {
      alertServiceLogger.d('Dettached Stream Subscription');
      _batchTimer?.cancel();
      _streamSubscription.cancel();
    });

    _rxMessageListener(_stream, filters);

    serviceReady.signal();

    return messageCount;
  }

  Future<Result<int, String>> _getRowCount(WebSocketChannel channel, Stream stream, AlertFilters filters) async {

    // await the ws connection before trying to send anything
    await _wsCompleter.future;

    alertServiceLogger.d('Asking backend for Alert row count via Websocket for range = ${filters.range}');

    // ask politely - Would you kindly...
    final request = jsonEncode([
      {'type': 'set-filters', ...filters.toDict()},
      {'type': 'request-size'}
    ]);
    channel.sink.add(request);

    // get the data
    final first = await stream.first;
    final decoded = jsonDecode(first) ?? 0;
    alertServiceLogger.d('_getRowCount recieved a message = $decoded');
    if (decoded['type'] == 'error') {

      return (Result.err(decoded['msg']));
    }
    if (decoded['type'] != 'request-size') {
      return Result.err('Expected row_count as first message');
    }

    return Result.ok(decoded['count'] as int);
  }

  void _rxMessageListener(Stream stream, AlertFilters filter,) {
    alertServiceLogger.d('Attached Stream Subscription');
    updatePageReadyFlag();
    _streamSubscription = stream.listen((message) {
      // FIXME: When no match filter is present, the rowID is preppended to the message
        final decoded = jsonDecode(message);

        if (decoded is Map && decoded.containsKey('type')) {
          final type = decoded['type'];
          if (type == 'error') {
            return _handleError(decoded['msg']);
          }
          if (type == 'request-size') {
            // ignore
            return;
          }
        }

        // alertServiceLogger.i('Stream Subscription recieved a message = $message');
        final row = AlertEvent.fromJsonArr(decoded);
        _pending.addLast(row);
        updatePageReadyFlag();
      },
      onError: _handleError,
      onDone: _handleDone
    );
  }

  Future<AlertTablePage> fetchPage(int page, AlertFilters filters) async {
    // 1. we wait for the service to be finished (initial request with row-count)
    await serviceReady.future;

    // 2. if we don't have any rows for this filters, we simply return early; we don't bother the backend
    if (messageCount == 0) {
      return AlertTablePage.empty(filters);
    }

    // 3. we have rows, let's request 'em mfers
    final request = jsonEncode({'type': 'request-data', 'count': AlertTablePage.pageSize});
    _channel.sink.add(request);

    // 4. we force a reevaluation of the status of the pending rows queue 
    // and await there's enough rows to form a page
    updatePageReadyFlag();
    await pageReady.future;

    // 5. we take the rows, and remove them from the _pending Queue
    final pageMessageCount = min(min(AlertTablePage.pageSize, messageCount),  _pending.length);
    final messages = _pending.takeAndRemove(pageMessageCount);

    // 6. we could have taken enought to leave less than a page-worth of items, so we need to reevaluate
    updatePageReadyFlag();
    
    // 7. we return the page for TrinaGrid to process it
    final syslogPage = AlertTablePage(
      messageCount: messageCount,
      events: Map.fromEntries(messages.map((msg) => MapEntry(msg.id, msg))),
      filters: ref.watch(alertFilterProvider)
    );

    return Future.value(syslogPage);
  }

  void onDateSelect(TrinaGridStateManager stateManager, DateTimeRange range, WidgetRef ref) async {
    final notifier = ref.read(alertFilterProvider.notifier);
    final filters = ref.read(alertFilterProvider);
    notifier.setFilters(filters.copyWith(range: range));
    
    await ref.watch(alertDbServiceProvider.notifier).serviceReady.future;
  
    stateManager.setColumnFilter(
      columnField: 'date_range_filter', // Clave única para su filtro global
      filterType: TrinaFilterTypeContains(), // O un tipo de filtro genérico
      filterValue: '${range.start.toString()}|${range.end.toString()}', 
    );
  }

  void onTristateToggle<T>(bool state, AlertTablePage cache, WidgetRef ref) {
    // Update filters, so the widget gets recreated and now subscribes to a alertDbServiceProvider with the new filters
    // causing the recreation of the table with these new filters
    final notifier = ref.read(alertFilterProvider.notifier);
    final filters = ref.read(alertFilterProvider);
    notifier.setFilters(filters.toggleFilterClass<T>(state));
    ref.read(dialogRebuildProvider.notifier).markDirty();
    
  }

  void onFilterChange(TrinaGridStateManager stateManager, dynamic filter, bool? state, WidgetRef ref) {
    ref.read(alertDbServiceProvider).whenData(
      (cache) {
        // Update filters, so the widget gets recreated and now subscribes to a alertDbServiceProvider with the new filters
        // causing the recreation of the table with these new filters
        final notifier = ref.read(alertFilterProvider.notifier);
        final filters = ref.read(alertFilterProvider);
        notifier.setFilters(filters.applySetFilter(filter, state));
        ref.read(dialogRebuildProvider.notifier).markDirty();
        final columnField = filter is AlertSeverity ? 'Severity'  : 'Unknown filter';
        final value = filter is AlertSeverity ? filters.severities.toString()  : 'Unknown filter value';

        stateManager.setColumnFilter(
          columnField: columnField, // Clave única para su filtro global
          filterType: TrinaFilterTypeContains(), // O un tipo de filtro genérico
          filterValue: value, 
        );
      },
    );
  }

  // TODO: Range filters
  void onMsgFilterChange(String value, WidgetRef ref) {
    _msgDebouncer.run(() {
      final filters = ref.read(alertFilterProvider);
      ref.watch(alertFilterProvider.notifier).setFilters(filters.copyWith(message: value));
    });
  }

  void onAckActorFilterChange(String value, WidgetRef ref) {
    _ackActorDebouncer.run(() {
      final filters = ref.read(alertFilterProvider);
      ref.watch(alertFilterProvider.notifier).setFilters(filters.copyWith(ackActor: value));
    });
  }

  void onTargetIdFilterChange(int value, WidgetRef ref) {
    _targetIdDebouncer.run(() {
      final filters = ref.read(alertFilterProvider);
      ref.watch(alertFilterProvider.notifier).setFilters(filters.copyWith(targetId: value));
    });
  }

  void onAlertIdFilterChange(int value, WidgetRef ref) {
    _alertIdDebouncer.run(() {
      final filters = ref.read(alertFilterProvider);
      ref.watch(alertFilterProvider.notifier).setFilters(filters.copyWith(alertId: value));
    });
  }

  void onRequiresAckFilterChange(bool value, WidgetRef ref) {
    _alertIdDebouncer.run(() {
      final filters = ref.read(alertFilterProvider);
      ref.watch(alertFilterProvider.notifier).setFilters(filters.copyWith(requiresAck: value));
    });
  }


  void updatePageReadyFlag() {
    bool ready = _pending.length >= AlertTablePage.pageSize;
    bool empty = messageCount == 0;
    bool lastPageReady = messageCount % AlertTablePage.pageSize == _pending.length;
    if ( ready || empty || lastPageReady ) {
      pageReady.signal();
    } else {
      pageReady.reset();
    }
  }

  void _handleError(dynamic error) {
    logger.e('WebSocket error: $error');
    state = AsyncValue.error(error, StackTrace.current);
  }

  void _handleDone() {
    logger.w('WebSocket connection closed');
    // Optionally update state or trigger reconnection
  }

}
