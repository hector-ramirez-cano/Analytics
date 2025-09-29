import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:shimmer/shimmer.dart';

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
  final available = context.cell.value != null;

  if (available) {
    return Text(context.cell.value.toString(), style: TextStyle(color: Colors.black),);
  }
  
  return shimmer;
}

final List<PlutoColumn> columns = [
      PlutoColumn(
        title: "Origen",field: "Origin",
        type: PlutoColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64),

      PlutoColumn(
        title: "Recibido", field: "RecievedAt",
        type: PlutoColumnType.date(format: "yyyy-MM-dd hh:mm:ss"), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 50),

      PlutoColumn(
        title: "Facility", field: "Facility",
        type: PlutoColumnType.select(SyslogFacility.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      PlutoColumn(
        title: "Severidad", field: "Severity",
        type: PlutoColumnType.select(SyslogSeverity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      PlutoColumn(
        title: "PID", field: "PID",
        type: PlutoColumnType.number(negative: false, format: "########"), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 32,),

      PlutoColumn(
        title: "Mensaje", field: "Message",
        type: PlutoColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,),
    ];
