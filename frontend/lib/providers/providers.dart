
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/canvas/canvas_interaction_service.dart';

import '../services/topology_service.dart';

final _topologyServiceProvider = Provider<TopologyService>((ref) {
  return TopologyService(
    endpoint: Uri.parse(AppConfig.getOrDefault("api/topology_endpoint")),
  );
});

final topologyProvider = FutureProvider<Topology>((ref) async {
  final service = ref.watch(_topologyServiceProvider);

  return service.fetchItems();
});

final canvasInteractionServiceProvider = Provider<CanvasInteractionService>((ref) {
  return CanvasInteractionService();
});
