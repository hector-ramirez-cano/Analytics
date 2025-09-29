import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';
import 'package:trina_grid/trina_grid.dart';
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

Widget columnRenderer(TrinaColumnRendererContext context) {
  final available = context.cell.value != null;

  if (available) {
    return Text(context.cell.value.toString(), style: TextStyle(color: Colors.black),);
  }
  
  return shimmer;
}

final List<TrinaColumn> columns = [
      TrinaColumn(
        title: "Origen",field: "Origin",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 64),

      TrinaColumn(
        title: "Recibido", field: "RecievedAt",
        type: TrinaColumnType.date(format: "yyyy-MM-dd hh:mm:ss"), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 50),

      TrinaColumn(
        title: "Facility", field: "Facility",
        type: TrinaColumnType.select(SyslogFacility.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      TrinaColumn(
        title: "Severidad", field: "Severity",
        type: TrinaColumnType.select(SyslogSeverity.values), renderer: columnRenderer,
        enableSorting: true, enableFilterMenuItem: true, width: 32),

      TrinaColumn(
        title: "PID", field: "PID",
        type: TrinaColumnType.number(negative: false, format: "########"), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true, width: 32,),

      TrinaColumn(
        title: "Mensaje", field: "Message",
        type: TrinaColumnType.text(), renderer: columnRenderer,
        enableSorting: false, enableFilterMenuItem: true,),
    ];
