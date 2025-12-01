enum ChartType {
  lineChart,
  pieChart,
  label;

  static ChartType? fromString(String str) {
    final value = str.toLowerCase();
    if (value == "line") { return ChartType.lineChart; }
    if (value == "pie" ) { return ChartType.pieChart;  }
    if (value == "label"){ return ChartType.label;     }

    return null;
  }
}

abstract class DashboardPollingDefinition {
  final List<String> fields;
  final int groupableId;
  final ChartType chartType;

  DashboardPollingDefinition({
    required this.fields,
    required this.groupableId,
    required this.chartType,
  });
}