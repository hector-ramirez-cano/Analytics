import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/services/syslog_db_service.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';
import 'package:network_analytics/ui/components/dialogs/checklist_dialog.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/syslog/log_table_columns.dart';
import 'package:trina_grid/trina_grid.dart';

class LogTable extends StatefulWidget {

  final Topology topology;

  const LogTable({
    super.key,
    required this.topology,
  });

  @override
  State<LogTable> createState() => _LogTableState();
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

enum LogTableStateScreen{
    loading, error, ready
}

class _LogTableState extends State<LogTable> {
  late TrinaGridStateManager stateManager;
  Map<int, TrinaRow> rowMap = {};

  late DateTimeRange _selectedDateRange;
  late SyslogFilters _filters;

  @override void initState() {
    super.initState();
  
    _selectedDateRange = _nowEmptyDateTimeRange();
    _filters = SyslogFilters.empty();
  }

  Widget _makeRetryIndicator(WidgetRef ref, BuildContext context, dynamic err, StackTrace? st) {
    void onRetry() async {
      // TODO: Reinstate invalidation
      //final _ = ref.invalidate(syslogTableProvider.from);
    }

    return Center(
      child: RetryIndicator(onRetry: () async => onRetry(), isLoading: err == null, error: err,)
    );
  }

  /// Generates a stable single [Key] from the [rowID], for unique identification within the LogTable
  Key _genRowKey(int rowId) {
    return Key("LogTable${(rowId).toString()}");
  }

  /// Generates a [TrinaRow] with empty cell, with a stable Row [Key] generated from it's finalIndex = [index] + [indexOffset]
  TrinaRow _genEmptyRow(int index, int indexOffset) {
    final row = TrinaRow(
        key: _genRowKey(index+indexOffset),
        cells: {
          'Origin'    : TrinaCell(value: null),
          'RecievedAt': TrinaCell(value: null),
          'Facility'  : TrinaCell(value: null),
          'Severity'  : TrinaCell(value: null),
          'PID'       : TrinaCell(value: null),
          'Message'   : TrinaCell(value: null),
        },
      );

      rowMap[index+indexOffset] = row;
      return row;
  }

  /// Generates a [List] of empty [TrinaRows], and updates the reserved Queue found in [cache],
  /// indicating the row is allocated, but waiting  to be hydrated
  List<TrinaRow> _genEmptyRows(SyslogTableCache cache) { 
    int rowCount = cache.messageCount != 0 ? cache.requestedCount : 0;
    int indexOffset = cache.reserveRows(rowCount);
    return List.generate(rowCount, ((index) => _genEmptyRow(index, indexOffset)));
  }

  Widget _makeLogTable(SyslogTableCache cache, WidgetRef ref, BuildContext context,)  {
    isFilterSelectedFn(filter) { 
      // Watch only used for reeval, might be removable, though
      ref.watch(syslogDbServiceProvider(_selectedDateRange, _filters));

      // Consult local stateful version of _filters, as the provider might still be building, requesting log count
      return _filters.hasSetFilter(filter);
    }

    onFilterDialogClose() {
      final _ = ref.refresh(syslogDbServiceProvider(_selectedDateRange, _filters));
    }

    onTristateToggle<T>(bool state) {
      // Update local state, so the widget gets recreated and now subscribes to a syslogDbServiceProvider with the new filters
      // causing the recreation of the table with these new filters
      setState(() {
        _filters = cache.filters.toggleFilterClass<T>(state);
        ref.read(dialogRebuildProvider.notifier).markDirty();
      });
    }

    onFilterChange(filter, bool? state) {
      ref.read(syslogDbServiceProvider(_selectedDateRange, _filters)).when(
        data: (cache) =>  setState(() {
          // Update local state, so the widget gets recreated and now subscribes to a syslogDbServiceProvider with the new filters
          // causing the recreation of the table with these new filters
          _filters = cache.filters.applySetFilter(filter, state);
          ref.read(dialogRebuildProvider.notifier).markDirty();
        }),
        error: (_, _) => {},
        loading: () => {},
      );
    }

    TrinaFilterColumnWidgetDelegate makeFilterColumnWidgetDelegate<T>(List<T> values) {
      return TrinaFilterColumnWidgetDelegate.builder(
          filterWidgetBuilder:(focusNode, controller, enabled, handleOnChanged, stateManager) {
            return OutlinedButton.icon(
              icon: Icon(Icons.filter_alt, ),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(_filters.setHasFilters<T>() ? Colors.amber : Colors.transparent),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))))
              ),
              label: Text(""),
              iconAlignment: IconAlignment.end,
              onPressed: () => ChecklistDialog<T>(
                options: values.toSet(),
                onChanged: onFilterChange,
                onClose: onFilterDialogClose,
                isSelectedFn: isFilterSelectedFn,
                onTristateToggle: (state) => onTristateToggle<T>(state)
              ).show(context), 
            );
          }
        );
    }

    // TODO: Alter text filters to update backend
    final List<TrinaColumn> columns = [
      TrinaColumn(
        title: "Facility", field: "Facility",
        renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32,
        type: TrinaColumnType.select(
          SyslogFacility.values, itemToString: (item) => item.toString(),
        ),
        filterWidgetDelegate: makeFilterColumnWidgetDelegate(SyslogFacility.values)
      ),

      TrinaColumn(
        title: "Severidad", field: "Severity",
        type: TrinaColumnType.select(SyslogSeverity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32,
        filterWidgetDelegate: makeFilterColumnWidgetDelegate(SyslogSeverity.values)
      ),

      TrinaColumn(
        title: "Origen",field: "Origin",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64),


      TrinaColumn(
        title: "Recibido", field: "RecievedAt",
        type: TrinaColumnType.date(format: "yyyy-MM-dd hh:mm:ss"), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 50),

      TrinaColumn(
        title: "PID", field: "PID",
        type: TrinaColumnType.number(negative: false, format: "########"), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 32,),

      TrinaColumn(
        title: "Mensaje", field: "Message",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,),
    ];


    // TODO: handle retries and loading
    return TrinaGrid(
      columns: columns,
      rows: [],
      onLoaded: (TrinaGridOnLoadedEvent event) {
        stateManager = event.stateManager;
        stateManager.setShowColumnFilter(true);

        stateManager.scroll.vertical!.addOffsetChangedListener(() {
          final double offset = stateManager.scroll.verticalOffset;
          final double maxOffset = stateManager.scroll.maxScrollVertical;
          if (maxOffset - offset < 200) {
            final notifier = ref.read(syslogDbServiceProvider(_selectedDateRange, _filters).notifier);

            notifier.requestMoreRows(10);
          }
        });

      },
      configuration: TrinaGridConfiguration(
        enableMoveHorizontalInEditing: true,
        columnSize: TrinaGridColumnSizeConfig(
          autoSizeMode: TrinaAutoSizeMode.scale,
          resizeMode: TrinaResizeMode.normal
        ),
      ),
      onChanged: null,
      mode: TrinaGridMode.readOnly,
    );
  }

  Widget _makeLogTableArea(WidgetRef ref, BuildContext context) {
    ref.listen(syslogDbServiceProvider(_selectedDateRange, _filters), (AsyncValue<SyslogTableCache>? prev, AsyncValue<SyslogTableCache>? next) {
      next?.when(
        error: (_, _) => {},
        loading: () => {},
        data: (cache) {
          // update the mfer
          // new items created
          if (cache.state == SyslogTableCacheState.updating) {
            final int offset = cache.getNextRowIndex();

            // if we're outpacing the hydration, don't append more than once
            final List<TrinaRow> shimmerRows = _genEmptyRows(cache);
            stateManager.appendRows(shimmerRows);
            stateManager.notifyListeners();

            Logger().d("updating table, appended = ${shimmerRows.length} starting at $offset, new Offset = ${cache.getNextRowIndex()}");
          
          } 
          
          // items got hydrated
          else if (cache.state == SyslogTableCacheState.hydrated) {
            Logger().d("hydrating table");
            for (var messageId in cache.hydratedRows) {
              final message = cache.messages[messageId];
              final rowIndex = cache.messageMapping[message?.id];
              var plutoRow = rowMap.remove(rowIndex);// rowMap[rowIndex];

              if (plutoRow == null) {
                plutoRow = _genEmptyRow(message!.id, cache.getNextRowIndex());
                stateManager.rows.add(plutoRow);
              }

              plutoRow.cells['Origin'    ]?.value = message?.source;
              plutoRow.cells['RecievedAt']?.value = message?.recievedAt;
              plutoRow.cells['Facility'  ]?.value = message?.facility;
              plutoRow.cells['Severity'  ]?.value = message?.severity;
              plutoRow.cells['PID'       ]?.value = message?.processId;
              plutoRow.cells['Message'   ]?.value = message?.message;
            }

            stateManager.notifyListeners();
          }
        },
      );
    });

    return _makeLogTable(SyslogTableCache.empty(_selectedDateRange, _filters), ref, context);
  }

  @override
  Widget build(BuildContext conRetryontext) {
    return Consumer(builder:(context, ref, child) {
      void onDateSelect(DateTimeRange range) {
        setState(() { _selectedDateRange = range; });
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DateRangePicker(initialRange: _selectedDateRange, onChanged: onDateSelect,),
          SizedBox(height: 24,),
          Expanded(child: _makeLogTableArea(ref, context))
        ],),
      );
    }
    );
  }
}