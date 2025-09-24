import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/services/syslog_table_service.dart';

import '../services/topology_service.dart';

final _topologyServiceProvider = Provider<TopologyService>((ref) {
  return TopologyService(
    endpoint: Uri.parse(AppConfig.getOrDefault("api/topology_endpoint")),
  );
});

final _syslogTableServiceProvider = Provider<SyslogTableService>((ref) {
  return SyslogTableService(
    endpoint: Uri.parse(AppConfig.getOrDefault("api/syslog_count_endpoint")),
  );
});


final topologyProvider = FutureProvider<Topology>((ref) async {
  final service = ref.watch(_topologyServiceProvider);

  return service.fetchItems();
});

final syslogTableProvider = FutureProvider<SyslogTableCache>((ref) async {
  final service = ref.watch(_syslogTableServiceProvider);

  final range = DateTimeRange(start: DateTime(2025, 9, 1), end: DateTime(2025, 9, 15));

  return service.fetchItems(range);
});


final canvasInteractionServiceProvider = Provider<CanvasInteractionService>((ref) {
  return CanvasInteractionService();
});