import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/alerts/alert_event.dart';
import 'package:aegis/models/alerts/alert_severity.dart';
import 'package:aegis/models/alerts/alert_table_page.dart';
import 'package:aegis/services/alerts/alert_db_service.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:aegis/ui/components/date_range_picker.dart';
import 'package:aegis/ui/components/dialogs/checklist_dialog.dart';
import 'package:aegis/ui/components/dialogs/syslog_table_info_dialog.dart';
import 'package:aegis/ui/screens/syslog/log_table_columns.dart';
import 'package:trina_grid/trina_grid.dart';

class AlertViewer extends ConsumerStatefulWidget {
  const AlertViewer({super.key});

  @override
  ConsumerState<AlertViewer> createState() => _AlertViewerState();
}

class _AlertViewerState extends ConsumerState<AlertViewer> {
  static const Duration _debounceDuration = Duration(milliseconds: 1000);

  late TrinaGridStateManager _stateManager;

  // TODO: Sorting
  Future<TrinaLazyPaginationResponse> pageFetch(TrinaLazyPaginationRequest request, WidgetRef ref) async {

    // 1. Show loading
    _stateManager.setShowLoading(true, level: TrinaGridLoadingLevel.rows);

    // 2. If the user jumped pages, we need to offset
    final filters = ref.read(alertFilterProvider);
    final notif = ref.read(alertFilterProvider.notifier);
    notif.setFilters(filters.copyWith(offset: (request.page - 1) * AlertTablePage.pageSize));
    
    // 3. try fetching
    try {
      final notifier = ref.watch(alertDbServiceProvider.notifier);

      // wait for the service to be ready (setting up ws, getting the totalMessageCount, and attaching the listeners)
      await notifier.serviceReady.future;

      if(!mounted) return TrinaLazyPaginationResponse(totalPage: 0, rows: [], totalRecords: 0);

      final filters = ref.read(alertFilterProvider);
      final page = await notifier.fetchPage(request.page, filters);
      return TrinaLazyPaginationResponse(totalPage: page.pageCount, rows: _genRowsFromPage(page), totalRecords: page.messageCount);
    }
    catch(e, _) {
      alertServiceLogger.e('Attempt to use ref after context was dismounted, no further action is required, $e');
      return TrinaLazyPaginationResponse(totalPage: 0, rows: [], totalRecords: 0);
    }
    finally {

      // 4. Stop the lading animation, regardless of whether if completed, or failed
      _stateManager.setShowLoading(false);
    }

  }

  TrinaFilterColumnWidgetDelegate _makeEnumWidgetDelegate<T>(List<T> values, AlertTablePage cache, WidgetRef ref) {
    final filters = ref.watch(alertFilterProvider);

    return TrinaFilterColumnWidgetDelegate.builder(
      filterWidgetBuilder:(focusNode, controller, enabled, handleOnChanged, stateManager) {
        return OutlinedButton.icon(
          icon: Icon(Icons.filter_alt, ),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(filters.setHasFilters<T>() ? Colors.amber : Colors.transparent),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))))
          ),
          label: Text(''),
          iconAlignment: IconAlignment.end,
          onPressed: () => ChecklistDialog<T>(
            options: values.toSet(),
            onChanged: (dynamic filter, state) => _onFilterChange(filter, state, ref),
            onClose: () => _onFilterDialogClose(ref),
            isAvailable: (_) => true,
            isSelectedFn: (filter) => _isFilterSelectedFn(filter, ref),
            onTristateToggle: (state) => _onTristateToggle<T>(state, cache, ref)
          ).show(context),
        );
      }
    );
}

  void _onDateSelect(DateTimeRange range, WidgetRef ref) => ref.read(alertDbServiceProvider.notifier).onDateSelect(_stateManager, range, ref);

  void _onTristateToggle<T>(bool state, AlertTablePage cache, WidgetRef ref) => ref.read(alertDbServiceProvider.notifier).onTristateToggle<T>(state, cache, ref);

  void _onFilterChange(dynamic filter, bool? state, WidgetRef ref) => ref.read(alertDbServiceProvider.notifier).onFilterChange(_stateManager, filter, state, ref);

  void _onRetry(WidgetRef ref) async { ref.invalidate(websocketServiceProvider); }

  void _onFilterDialogClose(WidgetRef ref) {}

  bool _isFilterSelectedFn(dynamic filter, WidgetRef ref) {
    // Consult local stateful version of _filters, as the provider might still be building, requesting log count
    return ref.watch(alertFilterProvider).hasSetFilter(filter);
  }

  void _onTrinaGridLoaded(TrinaGridOnLoadedEvent event, WidgetRef ref) {
    _stateManager = event.stateManager;

    _stateManager.setShowColumnFilter(true);

    // set not loading
    _stateManager.setShowLoading(false);


    _stateManager.eventManager!.listener((event) {
      if (event is! TrinaGridChangeColumnFilterEvent) { return; }

      if (event.column.field == 'ID') {
        ref.read(alertDbServiceProvider.notifier).onAlertIdFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'RequiresAck') {
        ref.read(alertDbServiceProvider.notifier).onRequiresAckFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'TargetId') {
        ref.read(alertDbServiceProvider.notifier).onTargetIdFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'Message') {
        ref.read(alertDbServiceProvider.notifier).onMsgFilterChange(event.filterValue, ref);
      }

      if (event.column.field == 'AckActor') {
        ref.read(alertDbServiceProvider.notifier).onAckActorFilterChange(event.filterValue, ref);
      }
    });

  }
  /// Generates a stable single [Key] from the [rowID], for unique identification within the LogTable
  Key _genRowKey(int rowId) {
    return Key('LogTable${(rowId).toString()}');
  }

  /// Generates a [TrinaRow] with empty cell, with a stable Row [Key] generated from it's finalIndex = [index] + [indexOffset]
  TrinaRow _genRow(AlertEvent event) {
    final row = TrinaRow(
        key: _genRowKey(event.id),
        cells: {
          'AlertId'    : TrinaCell(value: event.id         ),
          'AlertTime'  : TrinaCell(value: event.alertTime  ),
          'RequiresAck': TrinaCell(value: event.requiresAck),
          'AckTime'    : TrinaCell(value: event.ackTime    ),
          'Severity'   : TrinaCell(value: event.severity   ),
          'Message'    : TrinaCell(value: event.message    ),
          'TargetId'   : TrinaCell(value: event.targetId   ), 
          'AckActor'   : TrinaCell(value: event.ackActor   ),
        },
      );
      return row;
  }

  /// Generates a [List] of [TrinaRows], from the given page
  List<TrinaRow> _genRowsFromPage(AlertTablePage page) {
    return page.events.values.map((monosodiumglutamate) => _genRow(monosodiumglutamate)).toList();
  }

  Widget _makeHeader(WidgetRef ref) {
    final filters = ref.read(alertFilterProvider);

    return Row(children: [
      IconButton(onPressed: () => _onRetry(ref), icon: Icon(Icons.replay), tooltip: 'Reiniciar la conexión',),
      Spacer(),
      DateRangePicker(initialRange: filters.range, onChanged: (range) => _onDateSelect(range, ref),),
      Spacer(),
      IconButton(onPressed: () => displayInfoDialog(context), icon: Icon(Icons.info), tooltip: 'Información adicional',),
    ],);
  }

  Widget _makeLogTable(AlertTablePage cache, WidgetRef ref)  {
    List<TrinaColumn> columns = [
      TrinaColumn(
        title: 'ID', field: 'AlertId',
        type: TrinaColumnType.number(negative: false, format: '########'), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 16,
      ),
      TrinaColumn(
        title: 'Req. Ack', field: 'RequiresAck',
        type: TrinaColumnType.boolean(trueText: '✔', falseText: '✖'), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: false, width: 16
      ),
      TrinaColumn(
        title: 'Alertado', field: 'AlertTime',
        type: TrinaColumnType.date(format: 'yyyy-MM-dd hh:mm:ss'), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: false, width: 50
      ),
      TrinaColumn(
        title: 'Ack', field: 'AckTime',
        type: TrinaColumnType.date(format: 'yyyy-MM-dd hh:mm:ss'), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: false, width: 50
      ),

      TrinaColumn(
        title: 'Severidad', field: 'Severity',
        type: TrinaColumnType.select(AlertSeverity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32,
        filterWidgetDelegate: _makeEnumWidgetDelegate(AlertSeverity.values, cache, ref)
      ),

      TrinaColumn(
        title: 'Mensaje', field: 'Message',
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,
      ),

      TrinaColumn(
        title: 'Disp.',field: 'TargetId',
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 16
      ),

      TrinaColumn(
        title: 'Responsable Ack',field: 'AckActor',
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64
      ),
    ];

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
    final filters = ref.read(alertFilterProvider);
    return _makeLogTable(AlertTablePage.empty(filters), ref);
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