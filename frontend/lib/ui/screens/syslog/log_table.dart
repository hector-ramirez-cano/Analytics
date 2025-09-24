import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_serverity.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:shimmer/shimmer.dart';


class LogTable extends StatefulWidget {

  final Topology topology;

  const LogTable({
    super.key,
    required this.topology,
  });

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  late PlutoGridStateManager stateManager;

  Widget _makeRetryIndicator(WidgetRef ref, BuildContext context, dynamic err, StackTrace? st) {
    void onRetry() async {
      final _ = ref.refresh(syslogTableProvider.future);
    }

    return Center(
      child: RetryIndicator(onRetry: () async => onRetry(), isLoading: err != null, error: err,)
    );
  }

  Widget _makeLogTable(SyslogTableCache cache) {

    final shimmer = Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: double.infinity,
          height: 16,
          color: Colors.grey[300],
        ),
      );

    Widget columnRenderer(PlutoColumnRendererContext context) {
      final row = context.rowIdx;
      final available = false;

      if (available) {
        return Text(context.cell.value.toString(), style: TextStyle(color: Colors.black),);
      }
      
      return shimmer;
      }

    List<PlutoColumn> columns = [
      PlutoColumn(
        title: "Origen",field: "Origin",
        type: PlutoColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64),

      PlutoColumn(
        title: "Recibido", field: "RecievedAt",
        type: PlutoColumnType.date(format: "yyyy-MM-dd   hh:mm:ss"), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 50),

      PlutoColumn(
        title: "Facility", field: "Facility",
        type: PlutoColumnType.select(SyslogFacility.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      PlutoColumn(
        title: "Severidad", field: "Severity",
        type: PlutoColumnType.select(SyslogServerity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      PlutoColumn(
        title: "PID", field: "PID",
        type: PlutoColumnType.number(negative: false, format: "########"), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 64,),

      PlutoColumn(
        title: "Mensaje", field: "Message",
        type: PlutoColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,),
    ];


    List<PlutoRow> rows = List.generate(cache.messageCount, (rowIndex) {
      return PlutoRow(
        cells: {
          'Origin'    : PlutoCell(value: null),
          'RecievedAt': PlutoCell(value: null),
          'Facility'  : PlutoCell(value: null),
          'Severity'  : PlutoCell(value: null),
          'PID'       : PlutoCell(value: null),
          'Message'   : PlutoCell(value: null),
        },
      );
    });

    final tableView = PlutoGrid(
        columns: columns,
        rows: rows,
        onLoaded: (PlutoGridOnLoadedEvent event) {
          stateManager = event.stateManager;
          stateManager.setShowColumnFilter(true); // Enable filters
        },
        configuration: PlutoGridConfiguration(
          enableMoveHorizontalInEditing: true,
          columnSize: PlutoGridColumnSizeConfig(
            autoSizeMode: PlutoAutoSizeMode.scale,
            resizeMode: PlutoResizeMode.normal
          ),

        ),
        onChanged: null,
        mode: PlutoGridMode.readOnly,
        
      );

    return tableView;
  }

  Widget _makeLogTableArea(WidgetRef ref, BuildContext context) {
    return ref.watch(syslogTableProvider).when(
      data   : (data   ) => _makeLogTable(data),
      loading: (       ) => _makeRetryIndicator(ref, context, null, null),
      error  : (err, st) => _makeRetryIndicator(ref, context, err, st) // TODO: Check why this retries
    );
  }

  @override
  Widget build(BuildContext conRetryontext) {
    return Consumer(builder:(context, ref, child) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DatePicker(),
          SizedBox(height: 24,),
          Expanded(child: _makeLogTableArea(ref, context))
        ],),
      );
    }
    );
  }
}