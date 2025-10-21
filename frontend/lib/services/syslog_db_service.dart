import 'dart:async';
import 'dart:collection';
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
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trina_grid/trina_grid.dart';

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
    final _ = ref.watch(websocketServiceProvider);

    serviceReady.reset();
    _pending.clear();

    final count = await getRowCount("syslog", filters, ref, _handleError);

    if (count.isErr()) {
      throw(count.err().expect("[ERROR]Error result doesn't contain an error message"), StackTrace.current);
    } else {
      messageCount = count.unwrap();
    }

    ref.onDispose(() {
      SyslogDbService.logger.d('Dettached Stream Subscription');
      _batchTimer?.cancel();
    });

    _rxMessageListener(filters);

    serviceReady.signal();

    return messageCount;
  }


  void _rxMessageListener(SyslogFilters filter,) {
    SyslogDbService.logger.d('Attached Stream Subscription');
    updatePageReadyFlag();
    ref.read(websocketServiceProvider.notifier).attachListener('syslog', (json) {
      final content = extractBody('syslog', json, _handleError);
      // if the message isn't addressed to this listener
        if (content == null) { return; }

        final row = SyslogMessage.fromJsonArr(content);
        _pending.addLast(row);
        updatePageReadyFlag();
    });
  }

  Future<SyslogTablePage> fetchPage(int page, SyslogFilters filters) async {
    // 1. we wait for the service to be finished (initial request with row-count)
    await serviceReady.future;

    // 2. if we don't have any rows for this filters, we simply return early; we don't bother the backend
    if (messageCount == 0) {
      return SyslogTablePage.empty(filters);
    }

    // 3. we have rows, let's request 'em mfers
    final request = {'type': 'request-data', 'count': SyslogTablePage.pageSize};
    ref.read(websocketServiceProvider.notifier).post('syslog', request);

    // 4. we force a reevaluation of the status of the pending rows queue 
    // and await there's enough rows to form a page
    updatePageReadyFlag();
    await pageReady.future;

    // 5. we take the rows, and remove them from the _pending Queue
    final pageMessageCount = min(min(SyslogTablePage.pageSize, messageCount),  _pending.length);
    final messages = _pending.takeAndRemove(pageMessageCount);

    // 6. we could have taken enought to leave less than a page-worth of items, so we need to reevaluate
    updatePageReadyFlag();
    
    // 7. we return the page for TrinaGrid to process it
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
    bool ready = _pending.length >= SyslogTablePage.pageSize;
    bool empty = messageCount == 0;
    bool lastPageReady = messageCount % SyslogTablePage.pageSize == _pending.length;
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

}
