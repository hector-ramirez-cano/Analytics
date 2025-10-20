import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:network_analytics/models/enums/facts_const_types.dart';
import 'package:network_analytics/ui/components/dashboard.dart';
import 'package:network_analytics/ui/screens/charts/chart.dart';

class ChartDashboard extends StatefulWidget {
  const ChartDashboard({super.key});

  @override
  State<ChartDashboard> createState() => _ChartDashboardState();
}

class _ChartDashboardState extends State<ChartDashboard> {
  // TODO: Get this from the DB or sum
  final _definition = '''{
    "dashboard": {
      "widgets": [
        {
          "row": 0,
          "rowSpan": 1,
          "column": 0,
          "columnSpan": 3,
          "metric": "icmp_rtt",
          "type": "number"
        },
        {
          "row" : 1,
          "rowSpan": 1,
          "column": 0,
          "columnSpan": 1,
          "metadata": "icmp_status",
          "type": "string"
        }
      ]
    }
  }''';


  List<int> rows = [0 ,1];
  List<int> rowSpans = [1, 1];
  List<int> columns = [0, 0];
  List<int> columnSpans = [2, 1];

  DashboardWidget _widgetFromDefinition(Map<String, dynamic> definition) {
    int row     = definition[  "row"  ] ?? 0;
    int rowSpan = definition["rowSpan"] ?? 1;
    int col     = definition["column" ] ?? 0;
    int colSpan = definition["columnSpan"] ?? 1;

    FactsDataTypes type = FactsDataTypes.fromString(definition["type"]) ?? FactsDataTypes.string;

    return DashboardWidget(row, rowSpan, col, colSpan, child: LineChartSample2());
  }

  Dashboard _fromDefinition(Map<String, dynamic> definition) {
    final List items = definition["dashboard"]["widgets"];
    final children = items.map((def) => _widgetFromDefinition(def)).toList();
    return Dashboard(children: children) ;
  }


  @override
  Widget build(BuildContext context) {
    // TODO: import from file or db
    return _fromDefinition(jsonDecode(_definition));

  }
}