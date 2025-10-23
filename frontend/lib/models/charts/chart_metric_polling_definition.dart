import 'package:logger/web.dart';

class ChartMetricPollingDefinition {
  final String start;
  final String field;
  final int deviceId;
  final Duration aggregateInterval;
  final Duration updateInterval;

  ChartMetricPollingDefinition({
    required this.start,
    required this.field,
    required this.deviceId,
    required this.aggregateInterval,
    required this.updateInterval,
  });

  static ChartMetricPollingDefinition? fromJson(Map<String, dynamic> json) {
    // fields with default value
    var start = json["start"] ?? "-1h";
    var aggregateInterval = json["aggregate-interval-s"] ?? 60;
    var updateInterval = json["update-interval-s"] ?? 120;
    
    // must have, if they're not present, definition is invalid
    var field = json["field"];
    var deviceId = json["device-id"];

    if (field == null || deviceId == null) {
      Logger().e("Parsed ChartMetricPollingDefinition fromJson with missing required values. 'field'=$field, deviceId=$deviceId");
      return null;
    }

    return ChartMetricPollingDefinition(
      start: start,
      field: field,
      deviceId: deviceId,
      aggregateInterval: Duration(seconds: aggregateInterval),
      updateInterval: Duration(seconds: updateInterval),
    );
  }
}