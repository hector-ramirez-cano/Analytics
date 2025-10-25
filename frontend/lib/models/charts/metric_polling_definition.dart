import 'package:logger/web.dart';
import 'package:network_analytics/models/charts/dashboard_polling_definition.dart';

class MetricPollingDefinition extends DashboardPollingDefinition {
  final String start;
  final Duration aggregateInterval;
  final Duration updateInterval;

  MetricPollingDefinition({
    required super.deviceId,
    required super.field,
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
    var deviceId = json["device-id"];
    var type = json["type"];

    if (field == null || deviceId == null || type == null) {
      Logger().f("Parsed ChartMetricPollingDefinition fromJson with missing required values. 'field'=$field, deviceId=$deviceId, type='$type'");
      return null;
    }

    if (type != "metric") {
      Logger().f("Parsed ChartMetricPollingDefinition expected 'type'=='metric', actual='$type'");
      return null;
    }

    return MetricPollingDefinition(
      start: start,
      field: field,
      deviceId: deviceId,
      aggregateInterval: Duration(seconds: aggregateInterval),
      updateInterval: Duration(seconds: updateInterval),
    );
  }

  String get metric => field;
}