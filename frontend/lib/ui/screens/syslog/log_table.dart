import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/syslog_db_service.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';
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

  DateTimeRange _selectedDateRange = _nowEmptyDateTimeRange();

  Widget _makeRetryIndicator(WidgetRef ref, BuildContext context, dynamic err, StackTrace? st) {
    void onRetry() async {
      // TODO: Reinstate invalidation
      //final _ = ref.invalidate(syslogTableProvider.from);
    }

    return Center(
      child: RetryIndicator(onRetry: () async => onRetry(), isLoading: err == null, error: err,)
    );
  }

  Key _genRowKey(int rowId) {
    return Key("LogTable${(rowId).toString()}");
  }

  TrinaRow _genShimmerRow(int index, int indexOffset) {
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

  List<TrinaRow> _genShimmerRows(SyslogTableCache cache) {
    int rowCount = cache.messageCount != 0 ? cache.requestedCount : 0;
    int indexOffset = cache.reserveRows(rowCount);
    return List.generate(rowCount, ((index) => _genShimmerRow(index, indexOffset)));
  }

  Widget _makeLogTable(SyslogTableCache cache, WidgetRef ref)  {
    // handle retries and loading
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
            final notifier = ref.read(syslogBufferProvider(_selectedDateRange).notifier);

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
    ref.listen(syslogBufferProvider(_selectedDateRange), (AsyncValue<SyslogTableCache>? prev, AsyncValue<SyslogTableCache>? next) {
      next?.when(
        error: (_, _) => {},
        loading: () => {},
        data: (cache) {
          // update the mfer
          // new items created
          if (cache.state == SyslogTableCacheState.updating) {
            final int offset = cache.getNextRowIndex();

            // if we're outpacing the hydration, don't append more than once
            final List<TrinaRow> shimmerRows = _genShimmerRows(cache);
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
                plutoRow = _genShimmerRow(message!.id, cache.getNextRowIndex());
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

    return _makeLogTable(SyslogTableCache.empty(_selectedDateRange), ref);
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