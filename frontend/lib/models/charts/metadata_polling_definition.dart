
import 'package:logger/logger.dart';
import 'package:aegis/models/charts/dashboard_polling_definition.dart';

class MetadataPollingDefinition extends DashboardPollingDefinition {
  final Duration updateInterval;

  /// List of item ids for which metadata will be queried.
  /// If groupableId in the constructor is a deviceId, it will become exactly one device on the itemIds
  /// If groupableId in the constructor is a groupId, it will become to as many devices as the group contains
  final itemIds = [];

  MetadataPollingDefinition({
    required super.groupableId,
    required super.fields,
    required super.chartType,
    required this.updateInterval,
  });

  static MetadataPollingDefinition? fromJson(Map<String, dynamic> json) {
    // fields with default value
    var updateInterval = json["update-interval-s"] ?? 120;
    
    // must have, if they're not present, definition is invalid
    var fields = json["fields"];
    var deviceId = json["device-ids"];
    var type = json["type"];
    var chartTypeStr = json["chart-type"];

    if (fields == null || deviceId == null || type == null || chartTypeStr == null) {
      Logger().e("Parsed MetadataPollingDefinition fromJson with missing required values. 'fields'=$fields, deviceId=$deviceId, type='$type', chartType='$chartTypeStr'");
      return null;
    }

    final chartType = ChartType.fromString(chartTypeStr.toString());

    if (chartType == null) {
      Logger().e("Parsed MetadataPollingDefinition from json with invalid chartType = $chartTypeStr");
      return null;
    }

    if (type != "metadata") {
      Logger().f("Parsed MetadataPollingDefinition expected 'type'=='metadata', actual='$type'");
      return null;
    }

    List<String> list = fields.whereType<String>().toList();

    return MetadataPollingDefinition(
      fields: list,
      groupableId: deviceId,
      updateInterval: Duration(seconds: updateInterval),
      chartType: chartType,
    );
  }

  String get metadata => fields.firstOrNull ?? "";
}