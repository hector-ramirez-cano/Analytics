import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/hover_interaction_service.dart';
import 'package:network_analytics/services/item_selection_service.dart';

import '../services/topology_service.dart';

final topologyServiceProvider = Provider<TopologyService>((ref) {
  return TopologyService(
    endpoint: Uri.parse(AppConfig.get("api")["toplogy_endpoint"]), // TODO: Handle timeout
  );
});

final topologyProvider = FutureProvider<Topology>((ref) async {
  final service = ref.watch(topologyServiceProvider);

  return service.fetchItems();
});

final canvasInteractionServiceProvider = Provider<CanvasInteractionService>((ref) {
  return CanvasInteractionService();
});

final itemSelectionProvider = StateNotifierProvider<ItemSelectionService, int?>(
  (ref) => ItemSelectionService(),
);

