import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/services/canvas_state_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';

import '../services/topology_service.dart';

final topologyServiceProvider = Provider<TopologyService>((ref) {
  return TopologyService(
    endpoint: Uri.parse(AppConfig.getOrDefault("api/topology_endpoint")),
  );
});

final topologyProvider = FutureProvider<Topology>((ref) async {
  final service = ref.watch(topologyServiceProvider);

  return service.fetchItems();
});

final canvasInteractionServiceProvider = Provider<CanvasInteractionService>((ref) {
  return CanvasInteractionService();
});

final canvasStateNotifier = StateNotifierProvider<CanvasStateNotifier, CanvasState>(
  (ref) => CanvasStateNotifier()
);

final itemSelectionNotifier = StateNotifierProvider<ItemSelectionNotifier, ItemSelection?>(
  (ref) => ItemSelectionNotifier(),
);

final screenSelectionNotifier = StateNotifierProvider<ScreenSelectionNotifier, ScreenSelection>(
  (ref) => ScreenSelectionNotifier()
);