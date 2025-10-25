
import 'package:logger/logger.dart';
import 'package:network_analytics/models/charts/dashboard_polling_definition.dart';

class MetadataPollingDefinition extends DashboardPollingDefinition {
  final Duration updateInterval;

  MetadataPollingDefinition({
    required super.deviceId,
    required super.field,
    required this.updateInterval,
  });

  static MetadataPollingDefinition? fromJson(Map<String, dynamic> json) {
    // fields with default value
    var updateInterval = json["update-interval-s"] ?? 120;
    
    // must have, if they're not present, definition is invalid
    var field = json["field"];
    var deviceId = json["device-id"];
    var type = json["type"];

    if (field == null || deviceId == null || type == null) {
      Logger().e("Parsed ChartMetadataPollingDefinition fromJson with missing required values. 'field'=$field, deviceId=$deviceId, type='$type'");
      return null;
    }

    if (type != "metadata") {
      Logger().f("Parsed MetadataPollingDefinition expected 'type'=='metadata', actual='$type'");
      return null;
    }


    return MetadataPollingDefinition(
      field: field,
      deviceId: deviceId,
      updateInterval: Duration(seconds: updateInterval),
    );
  }

  String get metadata => field;
}