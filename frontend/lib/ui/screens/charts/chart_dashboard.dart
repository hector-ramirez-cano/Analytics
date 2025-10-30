import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/charts/dashboard_polling_definition.dart';
import 'package:aegis/models/charts/metadata_polling_definition.dart';
import 'package:aegis/models/charts/metric_polling_definition.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/dashboard_service.dart';
import 'package:aegis/services/topology/topology_provider.dart';
import 'package:aegis/services/websocket_service.dart';
import 'package:aegis/ui/components/dashboard.dart';
import 'package:aegis/ui/components/retry_indicator.dart';
import 'package:aegis/ui/screens/charts/metadata_label.dart';
import 'package:aegis/ui/screens/charts/metadata_pie_chart.dart';
import 'package:aegis/ui/screens/charts/metric_line_chart.dart';

class ChartDashboard extends ConsumerStatefulWidget {
  
  
  const ChartDashboard({
    super.key
  });

  @override
  ConsumerState<ChartDashboard> createState() => _ChartDashboardState();
}

class _ChartDashboardState extends ConsumerState<ChartDashboard> {

  void onRetry() async { ref.invalidate(websocketServiceProvider); ref.invalidate(topologyServiceProvider); }

  DashboardWidget _widgetFromDashboardItem(DashboardItem item, Topology topology) {
    final Widget child;
    if (item.definition is MetadataPollingDefinition && item.definition.chartType == ChartType.pieChart) {
      child = MetadataPieChart(definition: item.definition as MetadataPollingDefinition);
    }
    else if (item.definition is MetadataPollingDefinition && item.definition.chartType == ChartType.label) {
      child = MetadataLabel(definition: item.definition as MetadataPollingDefinition);
    }

    else if (item.definition is MetricPollingDefinition && item.definition.chartType == ChartType.lineChart) {
      child = MetricLineChart(definition: item.definition as MetricPollingDefinition);
    }
    else {
      // TODO: Handle this via empty type
      throw UnimplementedError();
    }

    return DashboardWidget(
      item.rowStart,
      item.rowSpan,
      item.columnStart,
      item.columnSpan,
      child: child
    );
  }

  Dashboard _fromLayoutsWithTopology(Topology topology, List<DashboardLayout> layouts) {
    if (layouts.isEmpty) { return Dashboard(name: "", children: []); }

    final layout = layouts.first;

    final children = layout.items.map((item) => _widgetFromDashboardItem(item, topology)).toList();

    return Dashboard(name: layout.name, children: children);
  }

  Widget _fromLayouts(List<DashboardLayout> layouts) {
    final topologyAsync = ref.watch(topologyServiceProvider);

    return topologyAsync.when(
      error: (e, _) => RetryIndicator(onRetry: () async => onRetry, isLoading: false, error: e),
      loading: () => RetryIndicator(onRetry: () async => onRetry , isLoading: true),
      data: (topology) => _fromLayoutsWithTopology(topology, layouts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardFuture = ref.watch(dashboardServiceProvider);

    return dashboardFuture.when(
      data: (dashboards) => _fromLayouts(dashboards),
      error: (e, _) => RetryIndicator(onRetry: () async => onRetry, isLoading: false, error: e),
      loading: () => RetryIndicator(onRetry: () async => onRetry , isLoading: true)
    );

  }
}