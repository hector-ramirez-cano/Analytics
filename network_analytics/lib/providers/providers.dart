import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/hover_interaction_service.dart';

import '../services/topology_service.dart';

final topologyServiceProvider = Provider<TopologyService>((ref) {
  return TopologyService(
    endpoint: Uri.parse('http://localhost:5050/api/topology'), // TODO: Use actual endpoint
  );
});

final topologyProvider = FutureProvider<Topology>((ref) async {
  final service = ref.watch(topologyServiceProvider);

  return service.fetchItems();
});

final hoverInteractionServiceProvider = Provider<HoverInteractionService>((ref) {
  return HoverInteractionService();
});
