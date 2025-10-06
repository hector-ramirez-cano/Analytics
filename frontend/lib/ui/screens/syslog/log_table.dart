import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';
import 'package:network_analytics/models/syslog/syslog_table_page.dart';
import 'package:network_analytics/services/syslog_db_service.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';
import 'package:network_analytics/ui/components/dialogs/checklist_dialog.dart';
import 'package:network_analytics/ui/components/dialogs/syslog_table_info_dialog.dart';
import 'package:network_analytics/ui/screens/syslog/log_table_columns.dart';
import 'package:trina_grid/trina_grid.dart';

class LogTable extends StatefulWidget {
  const LogTable({
    super.key,
  });

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  static const Duration _debounceDuration = Duration(milliseconds: 1000);

  late TrinaGridStateManager _stateManager;

  int _prevPage = 0;

  @override void initState() {
    super.initState();
  }

  Future<TrinaLazyPaginationResponse> pageFetch(TrinaLazyPaginationRequest request, WidgetRef ref) async {
    
    // 1. Show loading
    _stateManager.setShowLoading(true, level: TrinaGridLoadingLevel.rows);

    // 2. If the user jumped pages, we need to offset
    // if, however, we're loading page 5 and previous was 4, we can just request as is
    if (_prevPage + 1 != request.page && _prevPage != request.page) {
      final filters = ref.read(syslogFilterProvider);
      final notif = ref.read(syslogFilterProvider.notifier);
      notif.setFilters(filters.copyWith(offset: (request.page - 1) * SyslogTablePage.pageSize));
    }

    // 3. try fetching
    try {
      final notifier = ref.watch(syslogDbServiceProvider.notifier);

      // wait for the service to be ready (setting up ws, getting the totalMessageCount, and attaching the listeners)
      await notifier.serviceReady.future;
      final page = await notifier.fetchPage(request.page);
      _prevPage = request.page;
      return TrinaLazyPaginationResponse(totalPage: page.pageCount, rows: _genRowsFromPage(page), totalRecords: page.messageCount);
    } finally {

      // 4. Stop the lading animation, regardless of whether if completed, or failed
      _stateManager.setShowLoading(false);
    }

  }

  TrinaFilterColumnWidgetDelegate _makeEnumWidgetDelegate<T>(List<T> values, SyslogTablePage cache, WidgetRef ref) {
    final filters = ref.watch(syslogFilterProvider);

    return TrinaFilterColumnWidgetDelegate.builder(
      filterWidgetBuilder:(focusNode, controller, enabled, handleOnChanged, stateManager) {
        return OutlinedButton.icon(
          icon: Icon(Icons.filter_alt, ),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(filters.setHasFilters<T>() ? Colors.amber : Colors.transparent),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))))
          ),
          label: Text(""),
          iconAlignment: IconAlignment.end,
          onPressed: () => ChecklistDialog<T>(
            options: values.toSet(),
            onChanged: (dynamic filter, state) => _onFilterChange(filter, state, ref),
            onClose: () => _onFilterDialogClose(ref),
            isSelectedFn: (filter) => _isFilterSelectedFn(filter, ref),
            onTristateToggle: (state) => _onTristateToggle<T>(state, cache, ref)
          ).show(context), 
        );
      }
    );
}

  void _onDateSelect(DateTimeRange range, WidgetRef ref) => ref.read(syslogDbServiceProvider.notifier).onDateSelect(_stateManager, range, ref);

  void _onTristateToggle<T>(bool state, SyslogTablePage cache, WidgetRef ref) => ref.read(syslogDbServiceProvider.notifier).onTristateToggle<T>(state, cache, ref);

  void _onFilterChange(dynamic filter, bool? state, WidgetRef ref) => ref.read(syslogDbServiceProvider.notifier).onFilterChange(_stateManager, filter, state, ref);

  void _onRetry(WidgetRef ref) async { ref.invalidate(syslogWsProvider); }

  void _onFilterDialogClose(WidgetRef ref) {}

  bool _isFilterSelectedFn(dynamic filter, WidgetRef ref) { 
    // Consult local stateful version of _filters, as the provider might still be building, requesting log count
    return ref.watch(syslogFilterProvider).hasSetFilter(filter);
  }

  void _onTrinaGridLoaded(TrinaGridOnLoadedEvent event, WidgetRef ref) {
    _stateManager = event.stateManager;
    
    _stateManager.setShowColumnFilter(true);

    // set not loading, and tell TrinaGrid which widget it should use
    _stateManager.setShowLoading(false, customLoadingWidget: shimmer);


    _stateManager.eventManager!.listener((event) {
      if (event is! TrinaGridChangeColumnFilterEvent) { return; }

      if (event.column.field == 'Message') {
        ref.read(syslogDbServiceProvider.notifier).onMsgFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'PID') {
        ref.read(syslogDbServiceProvider.notifier).onPidFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'Origin') {
        ref.read(syslogDbServiceProvider.notifier).onOriginFilterChange(event.filterValue, ref);
      }
    });
  }

  /// Generates a stable single [Key] from the [rowID], for unique identification within the LogTable
  Key _genRowKey(int rowId) {
    return Key("LogTable${(rowId).toString()}");
  }

  /// Generates a [TrinaRow] with empty cell, with a stable Row [Key] generated from it's finalIndex = [index] + [indexOffset]
  TrinaRow _genRow(SyslogMessage message) {
    final row = TrinaRow(
        key: _genRowKey(message.id),
        cells: {
          'Origin'    : TrinaCell(value: message.source    ),
          'RecievedAt': TrinaCell(value: message.recievedAt),
          'Facility'  : TrinaCell(value: message.facility  ),
          'Severity'  : TrinaCell(value: message.severity  ),
          'PID'       : TrinaCell(value: message.processId ),
          'Message'   : TrinaCell(value: message.message   ),
        },
      );
      return row;
  }

  /// Generates a [List] of [TrinaRows], from the given page
  List<TrinaRow> _genRowsFromPage(SyslogTablePage page) {
    return page.messages.values.map((monosodiumglutamate) => _genRow(monosodiumglutamate)).toList();
  }

  Widget _makeHeader(WidgetRef ref) {
    final filters = ref.read(syslogFilterProvider);

    return Row(children: [
      IconButton(onPressed: () => _onRetry(ref), icon: Icon(Icons.replay), tooltip: "Reiniciar la conexión",),
      Spacer(),
      DateRangePicker(initialRange: filters.range, onChanged: (range) => _onDateSelect(range, ref),),
      Spacer(),
      IconButton(onPressed: () => displayInfoDialog(context), icon: Icon(Icons.info), tooltip: "Información adicional",),
    ],);
  }

  Widget _makeLogTable(SyslogTablePage cache, WidgetRef ref)  {
    List<TrinaColumn> columns = [
      TrinaColumn(
        title: "Recibido", field: "RecievedAt",
        type: TrinaColumnType.date(format: "yyyy-MM-dd hh:mm:ss"), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: false, width: 50
      ),

      TrinaColumn(
        title: "Facility", field: "Facility",
        renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32,
        type: TrinaColumnType.select(
          SyslogFacility.values, itemToString: (item) => item.toString(),
        ),
        filterWidgetDelegate: _makeEnumWidgetDelegate(SyslogFacility.values, cache, ref)
      ),

      TrinaColumn(
        title: "Severidad", field: "Severity",
        type: TrinaColumnType.select(SyslogSeverity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32,
        filterWidgetDelegate: _makeEnumWidgetDelegate(SyslogSeverity.values, cache, ref)
      ),

      TrinaColumn(
        title: "Origen",field: "Origin",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64
      ),

      TrinaColumn(
        title: "PID", field: "PID",
        type: TrinaColumnType.number(negative: false, format: "########"), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 32,
      ),

      TrinaColumn(
        title: "Mensaje", field: "Message",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,
      ),
    ];

    // TODO: handle retries and loading
    return TrinaGrid(
      columns: columns,
      rows: [],
      onLoaded: (event) => _onTrinaGridLoaded(event, ref),
      configuration: TrinaGridConfiguration(
        columnFilter: TrinaGridColumnFilterConfig(
          debounceMilliseconds: _debounceDuration.inMilliseconds
        ),
        enableMoveHorizontalInEditing: true,
        columnSize: TrinaGridColumnSizeConfig(
          autoSizeMode: TrinaAutoSizeMode.scale,
          resizeMode: TrinaResizeMode.normal
        ),
      ),
      onChanged: null,
      mode: TrinaGridMode.readOnly,
      createHeader: (stateManager) => _makeHeader(ref),
      createFooter: (stateManager) => TrinaLazyPagination(fetch: (request) => pageFetch(request, ref), stateManager: stateManager)
      
    );
  }

  Widget _makeLogTableArea(WidgetRef ref) {
    final filters = ref.read(syslogFilterProvider);
    return _makeLogTable(SyslogTablePage.empty(filters), ref);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder:(context, ref, child) =>
    Padding(
        padding: const EdgeInsets.all(16),
        child: _makeLogTableArea(ref),
      )
    );
  }
}