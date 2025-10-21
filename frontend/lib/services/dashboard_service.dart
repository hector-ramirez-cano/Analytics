
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_service.g.dart';

class DashboardItem {
  final int rowStart;
  final int rowSpan;
  final int columnStart;
  final int columnSpan;
  final String? metric;
  final String? metadata;

  DashboardItem({
    required this.rowStart,
    required this.rowSpan,
    required this.columnStart,
    required this.columnSpan,
    required this.metric,
    required this.metadata,
  });

  factory DashboardItem.fromJson(Map<String, dynamic> items) {
    return DashboardItem(
      rowStart: items["row"],
      rowSpan: items["row-span"],
      columnStart: items["col"],
      columnSpan: items["col-span"],
      metric: items["metric"],
      metadata: items["metadata"],
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
  Semaphore _layoutsReady = Semaphore();

  @override
  Future<List<DashboardLayout>> build() async {
    final wsState = ref.watch(websocketServiceProvider);
    final notifier = ref.watch(websocketServiceProvider.notifier);
    layouts.clear();
    _layoutsReady.reset();

    await wsState.connected.future;

    notifier.attachListener("dashboards", (json) {
      final decoded = extractBody("dashboards", json, (e) => state = AsyncValue.error(e, StackTrace.current));

      if(decoded == null) { return; }

      layouts = fromJson(json["msg"]);
      _layoutsReady.signal();
    });

    notifier.post("dashboards", "{}");

    await _layoutsReady.future;
    return layouts;
  }
}