
import 'package:logger/logger.dart';
import 'package:aegis/models/charts/dashboard_polling_definition.dart';

class FactsPollingDefinition extends DashboardPollingDefinition {
  final Duration updateInterval;

  /// List of item ids for which metadata will be queried.
  /// If groupableId in the constructor is a deviceId, it will become exactly one device on the itemIds
  /// If groupableId in the constructor is a groupId, it will become to as many devices as the group contains
  final itemIds = [];

  FactsPollingDefinition({
    required super.groupableId,
    required super.fields,
    required super.chartType,
    required this.updateInterval,
  });

  static FactsPollingDefinition? fromJson(Map<String, dynamic> json) {
    // fields with default value
    var updateInterval = json["update-interval-s"] ?? 120;
    
    // must have, if they're not present, definition is invalid
    var fields = json["fields"];
    var deviceId = json["device-ids"];
    var type = json["type"];
    var chartTypeStr = json["chart-type"];

    if (fields == null || deviceId == null || type == null || chartTypeStr == null) {
      Logger().e("Parsed FactsPollingDefinition fromJson with missing required values. 'field'=$fields, deviceId=$deviceId, type='$type', chartType='$chartTypeStr'");
      return null;
    }

    final chartType = ChartType.fromString(chartTypeStr.toString());

    if (chartType == null) {
      Logger().e("Parsed FactsPollingDefinition from json with invalid chartType = $chartTypeStr");
      return null;
    }

    if (type != "facts") {
      Logger().f("Parsed FactsPollingDefinition expected 'type'=='facts', actual='$type'");
      return null;
    }


    return FactsPollingDefinition(
      fields: List.from(fields),
      groupableId: deviceId,
      updateInterval: Duration(seconds: updateInterval),
      chartType: chartType,
    );
  }

}