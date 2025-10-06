import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/debouncer.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/extensions/queue.dart';
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_filters.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';
import 'package:network_analytics/models/syslog/syslog_table_page.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:oxidized/oxidized.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'syslog_db_service.g.dart';

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

final syslogWsProvider = Provider<(WebSocketChannel, Stream, Completer)>((ref) {
  try {
    final endpoint = Uri.parse(AppConfig.getOrDefault('ws/syslog_ws_endpoint'));
    final channel = WebSocketChannel.connect(endpoint);
    final stream = channel.stream.asBroadcastStream();
    final connected = Completer<void>();


    SyslogDbService.logger.i('Attempting to start websocket on endpoint=$endpoint');
    // TODO: Handle onError
    channel.ready.then((_) {
      SyslogDbService.logger.d('Websocket channel ready');
      connected.complete();
    },
      onError: (err, st) => {
        SyslogDbService.logger.e('Websocket failed to connect with error = $err')
      }
    );

    ref.onDispose(() {
      channel.sink.close();
    });
  return (channel, stream, connected);
  } catch (e) {
    SyslogDbService.logger.e(e.toString());
    rethrow;
  }
});

@riverpod
class SyslogFilter extends _$SyslogFilter {
  @override
  SyslogFilters build() {
    return SyslogFilters.empty(_nowEmptyDateTimeRange());
  }

  void setFilters(SyslogFilters filters) {
    state = filters;
  }
}

@Riverpod(keepAlive: true)
class SyslogDbService extends _$SyslogDbService {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig('debug/enable_syslog_service_logging', false));
  late WebSocketChannel _channel;
  late Stream _stream;
  late Completer _wsCompleter;
  late StreamSubscription _streamSubscription;
  final Queue<SyslogMessage> _pending = Queue();
  Timer? _batchTimer;

  static const Duration _debounceDuration = Duration(milliseconds: 1000);
  final Debouncer _msgDebouncer    = Debouncer(delay: _debounceDuration);
  final Debouncer _pidDebouncer    = Debouncer(delay: _debounceDuration);
  final Debouncer _originDebouncer = Debouncer(delay: _debounceDuration);

  Semaphore pageReady = Semaphore();
  Semaphore serviceReady = Semaphore();
  int messageCount = 0;

  @override
  Future<int> build() async {
    SyslogDbService.logger.d('Recreating SyslogTablePage notifier!');
    final filters = ref.watch(syslogFilterProvider);
    final ws = ref.watch(syslogWsProvider);
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
      SyslogDbService.logger.d('Dettached Stream Subscription');
      _batchTimer?.cancel();
      _streamSubscription.cancel();
    });

    _rxMessageListener(_stream, filters);

    serviceReady.signal();

    return messageCount;
  }

  Future<Result<int, String>> _getRowCount(WebSocketChannel channel, Stream stream, SyslogFilters filters) async {

    // await the ws connection before trying to send anything
    await _wsCompleter.future;

    SyslogDbService.logger.d('Asking backend for row count via Websocket for range = ${filters.range}');

    // ask politely - Would you kindly...
    final request = jsonEncode([
      {'type': 'set-filters', ...filters.toDict()},
      {'type': 'request-size', ...filters.toDict()}
    ]);
    channel.sink.add(request);

    // get the data
    final first = await stream.first;
    final decoded = jsonDecode(first);
    SyslogDbService.logger.d('_getRowCount recieved a message = $decoded');
    if (decoded['type'] == 'error') {

      return (Result.err(decoded['msg']));
    }
    if (decoded['type'] != 'request-size') {
      return Result.err('Expected row_count as first message');
    }

    return Result.ok(decoded['count'] as int);
  }

  void _rxMessageListener(Stream stream, SyslogFilters filter,) {
    SyslogDbService.logger.d('Attached Stream Subscription');
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

        // SyslogDbService.logger.i('Stream Subscription recieved a message = $message');
        final row = SyslogMessage.fromJson(decoded);
        _pending.addLast(row);
        updatePageReadyFlag();
      },
      onError: _handleError,
      onDone: _handleDone
    );
  }

  // TODO: If returned rowCount was 0, return early from fetchPage
  Future<SyslogTablePage> fetchPage(int page) async {
    await serviceReady.future;
    final request = jsonEncode({'type': 'request-data', 'count': SyslogTablePage.pageSize});
    _channel.sink.add(request);

    updatePageReadyFlag();
    await pageReady.future;

    final pageMessageCount = min(min(SyslogTablePage.pageSize, messageCount),  _pending.length);
    final messages = _pending.takeAndRemove(pageMessageCount);

    // we could have taken enought to leave less than a page-worth of items, so we need to reevaluate
    updatePageReadyFlag();
    
    final syslogPage = SyslogTablePage(
      messageCount: messageCount,
      messages: Map.fromEntries(messages.map((msg) => MapEntry(msg.id, msg))),
      filters: ref.watch(syslogFilterProvider)
    );

    return Future.value(syslogPage);
  }

  void onDateSelect(TrinaGridStateManager stateManager, DateTimeRange range, WidgetRef ref) async {
    final notifier = ref.read(syslogFilterProvider.notifier);
    final filters = ref.read(syslogFilterProvider);
    notifier.setFilters(filters.copyWith(range: range));
    
    await ref.watch(syslogDbServiceProvider.notifier).serviceReady.future;
  
    stateManager.setColumnFilter(
      columnField: "date_range_filter", // Clave única para su filtro global
      filterType: TrinaFilterTypeContains(), // O un tipo de filtro genérico
      filterValue: "${range.start.toString()}|${range.end.toString()}", 
    );
  }

  void onTristateToggle<T>(bool state, SyslogTablePage cache, WidgetRef ref) {
    // Update filters, so the widget gets recreated and now subscribes to a syslogDbServiceProvider with the new filters
    // causing the recreation of the table with these new filters
    final notifier = ref.read(syslogFilterProvider.notifier);
    final filters = ref.read(syslogFilterProvider);
    notifier.setFilters(filters.toggleFilterClass<T>(state));
    ref.read(dialogRebuildProvider.notifier).markDirty();
    
  }

  void onFilterChange(TrinaGridStateManager stateManager, dynamic filter, bool? state, WidgetRef ref) {
    ref.read(syslogDbServiceProvider).whenData(
      (cache) {
        // Update filters, so the widget gets recreated and now subscribes to a syslogDbServiceProvider with the new filters
        // causing the recreation of the table with these new filters
        final notifier = ref.read(syslogFilterProvider.notifier);
        final filters = ref.read(syslogFilterProvider);
        notifier.setFilters(filters.applySetFilter(filter, state));
        ref.read(dialogRebuildProvider.notifier).markDirty();
        final columnField = filter is SyslogFacility ? "Facility" : filter is SyslogSeverity ? "Severity"  : "Unknown filter";
        final value = filter is SyslogFacility ? filters.facilities.toString() : filter is SyslogSeverity ? filters.severities.toString()  : "Unknown filter value";

        stateManager.setColumnFilter(
          columnField: columnField, // Clave única para su filtro global
          filterType: TrinaFilterTypeContains(), // O un tipo de filtro genérico
          filterValue: value, 
        );
      },
    );
  }

  void onMsgFilterChange(String value, WidgetRef ref) {
    _msgDebouncer.run(() {
      final filters = ref.read(syslogFilterProvider);
      ref.watch(syslogFilterProvider.notifier).setFilters(filters.copyWith(message: value));
    });
  }

  void onPidFilterChange(String value, WidgetRef ref) {
    _pidDebouncer.run(() {
      final filters = ref.read(syslogFilterProvider);
      ref.watch(syslogFilterProvider.notifier).setFilters(filters.copyWith(pid: value));
    });
  }

  void onOriginFilterChange(String value, WidgetRef ref) {
    _originDebouncer.run(() {
      final filters = ref.read(syslogFilterProvider);
      ref.watch(syslogFilterProvider.notifier).setFilters(filters.copyWith(origin: value));
    });
  }

  void updatePageReadyFlag() {
    // TODO: Load last page on messageCount not being divisible by pageSize
    if (_pending.length >= SyslogTablePage.pageSize || messageCount == 0) {
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
