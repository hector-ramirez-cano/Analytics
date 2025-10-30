import 'package:logger/web.dart';
import 'package:aegis/models/charts/dashboard_polling_definition.dart';

class MetricPollingDefinition extends DashboardPollingDefinition {
  final String start;
  final Duration aggregateInterval;
  final Duration updateInterval;

  MetricPollingDefinition({
    required super.groupableId,
    required super.field,
    required super.chartType,
    required this.start,
    required this.aggregateInterval,
    required this.updateInterval,
  });

  static MetricPollingDefinition? fromJson(Map<String, dynamic> json) {
    // fields with default value
    var start = json["start"] ?? "-1h";
    var aggregateInterval = json["aggregate-interval-s"] ?? 60;
    var updateInterval = json["update-interval-s"] ?? 120;
    
    // must have, if they're not present, definition is invalid
    var field = json["field"];
    var deviceIds = json["device-ids"];
    var type = json["type"];
    var chartTypeStr = json["chart-type"];

    if (field == null || deviceIds == null || type == null || chartTypeStr == null) {
      Logger().f("Parsed ChartMetricPollingDefinition fromJson with missing required values. 'field'=$field, deviceId=$deviceIds, type='$type', chartType='$chartTypeStr'");
      return null;
    }

        final chartType = ChartType.fromString(chartTypeStr.toString());

    if (chartType == null) {
      Logger().e("Parsed ChartMetricPollingDefinition from json with invalid chartType = $chartTypeStr");
      return null;
    }

    if (type != "metric") {
      Logger().f("Parsed ChartMetricPollingDefinition expected 'type'=='metric', actual='$type'");
      return null;
    }

    return MetricPollingDefinition(
      start: start,
      field: field,
      groupableId: deviceIds,
      aggregateInterval: Duration(seconds: aggregateInterval),
      updateInterval: Duration(seconds: updateInterval),
      chartType: chartType
    );
  }

  String get metric => field;
}