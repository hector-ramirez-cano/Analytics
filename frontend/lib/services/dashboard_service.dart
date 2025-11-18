
import 'package:aegis/extensions/semaphore.dart';
import 'package:aegis/models/charts/metadata_polling_definition.dart';
import 'package:aegis/models/charts/metric_polling_definition.dart';
import 'package:aegis/models/charts/dashboard_polling_definition.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_service.g.dart';

class DashboardItem {
  final int rowStart;
  final int rowSpan;
  final int columnStart;
  final int columnSpan;
  final DashboardPollingDefinition definition;

  DashboardItem({
    required this.rowStart,
    required this.rowSpan,
    required this.columnStart,
    required this.columnSpan,
    required this.definition,
  });

  static DashboardItem fromJson(Map<String, dynamic> items) {

    final DashboardPollingDefinition definition;
    final type = items['polling-definition']['type'];
    if (type == "metric") {
      definition = MetricPollingDefinition.fromJson(items['polling-definition'])!;
    } 
    else if (type == "metadata") {
      definition = MetadataPollingDefinition.fromJson(items['polling-definition'])!;
    }
    else {
      // TODO: Handle via empty definition type
      throw UnimplementedError();
    }

    if (
          items["row-start"] == null
      ||  items["row-span" ] == null
      ||  items["col-start"] == null
      ||  items["col-span" ] == null
    ) {
      Logger().w("Found dasboard item json definition with missing values. row-start=${items["row-start"]},row-span=${items["row-span"]},col-start=${items["col-start"]},col-span=${items["col-span"]}");
    }

    return DashboardItem(
      rowStart   : items["row-start"] ?? 0,
      rowSpan    : items["row-span"] ?? 1,
      columnStart: items["col-start"] ?? 0,
      columnSpan : items["col-span"] ?? 1,
      definition: definition
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

  List<DashboardLayout> fromJson(List<dynamic> json) {
    return json.map((value) => DashboardLayout.fromJson(value)).toList();
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
      if(decoded is! List) { return; }


      layouts = fromJson(decoded);
      _layoutsReady.signal();
    });

    notifier.post("dashboards", "{}");

    await _layoutsReady.future;
    return layouts;
  }
}