
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/charts/chart_metric_polling_definition.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_service.g.dart';

class DashboardItem {
  final int rowStart;
  final int rowSpan;
  final int columnStart;
  final int columnSpan;
  final ChartMetricPollingDefinition definition;

  DashboardItem({
    required this.rowStart,
    required this.rowSpan,
    required this.columnStart,
    required this.columnSpan,
    required this.definition,
  });

  static DashboardItem fromJson(Map<String, dynamic> items) {
    final definition = ChartMetricPollingDefinition.fromJson(items['polling-definition']);

    return DashboardItem(
      rowStart: items["row"] ?? 0,
      rowSpan: items["row-span"] ?? 1,
      columnStart: items["col"] ?? 0,
      columnSpan: items["col-span"] ?? 1,
      definition: definition! // TODO: Safe handling of null values
    );
  }
}

class DashboardLayout{
  List<DashboardItem> items;
  String name;

  DashboardLayout({required this.name, required this.items});

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    String name = json["name"];
    List widgetDefinitions = json["widgets"];
    List<DashboardItem> items = widgetDefinitions.map((innerJson) => DashboardItem.fromJson(innerJson)).toList();

    return DashboardLayout(name: name, items: items);
  }
}

@riverpod
class DashboardService extends _$DashboardService {

  List<DashboardLayout> fromJson(Map<String, dynamic> json) {
    return json.values.map((value) => DashboardLayout.fromJson(value)).toList();
  }

  List<DashboardLayout> layouts = [];
  final Semaphore _layoutsReady = Semaphore();

  @override
  Future<List<DashboardLayout>> build() async {
    final wsState = ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);
    layouts.clear();
    _layoutsReady.reset();

    await wsState.connected.future;

    notifier.attachListener("dashboards", "dashboards", (json) {
      final decoded = extractBody("dashboards", json, (e) => state = AsyncValue.error(e, StackTrace.current));

      if(decoded == null) { return; }
      if(decoded is! Map) { return; }

      layouts = fromJson(json["msg"]);
      _layoutsReady.signal();
    });

    notifier.post("dashboards", "{}");

    await _layoutsReady.future;
    return layouts;
  }
}