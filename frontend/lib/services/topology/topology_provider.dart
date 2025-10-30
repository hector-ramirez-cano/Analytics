import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'topology_provider.g.dart';

@riverpod
class TopologyService extends _$TopologyService {
  Topology? _parsed;

  final Semaphore _firstRun = Semaphore();

  
  void onTopology(Map<String, dynamic> response) {
    // TODO: Status on initial response
    _parsed = Topology.fromJson(response["msg"]);

    state = AsyncValue.data(_parsed!);
    _firstRun.signal();
  }


  void onLink(Map<String, dynamic> response) {
    if (_parsed == null) return;
    if (response["type"] != "link") return;

    final Map<int, AnalyticsItem> itemsCopy = Map.from(_parsed!.items);

    for (MapEntry<String, dynamic> deviceEntry in response["msg"].entries) {
      final device = _parsed!.getDeviceByHostname(deviceEntry.key);

      if (device == null) continue;

      // TODO: Add snmp as a status updater
      final statusMap = deviceEntry.value;
      bool? status;

      // if no entry contains a status, it's completely unknown
      if (statusMap.values.every((statusEntry) => !statusEntry.containsKey("status"))) {
        status = null;
      } else {
        status = statusMap.values.any((statusEntry) => statusEntry["status"] == "REACHABLE");
      }

      itemsCopy[device.id] = (_parsed!.items[device.id] as Device).copyWith(reachable: status);
    }

    _parsed = _parsed!.copyWith(items: itemsCopy);

    if (_firstRun.isComplete) {
      state = AsyncValue.data(_parsed!);
    }
  }

  @override
  Future<Topology> build() async {
    final wsState = ref.watch(websocketServiceProvider) ;
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _firstRun.reset();
    await wsState.connected.future;

    notifier.attachListener("topology", "topology", onTopology);
    notifier.attachListener("link", "link", onLink);

    notifier.post("topology", "{}");

    await _firstRun.future;
    return _parsed!;
  }
}