import 'dart:collection';

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

  Widget _makeEmptyDashboardSelection() {
    return SizedBox.expand(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // keeps the column as small as possible
          children: [
            Spacer(),
            Icon(Icons.category_outlined, size: 128, color: Colors.blueGrey,),
            SizedBox(height: 12), // spacing between icon and text
            Text("Selecciona un dashboard"),
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _fromLayoutsWithTopology(Topology topology, HashMap<int, DashboardLayout> layouts, int selected) {
    if (layouts.isEmpty || !layouts.containsKey(selected)) { return _makeEmptyDashboardSelection(); }

    final layout = layouts[selected]!;

    final children = layout.items.map((item) => _widgetFromDashboardItem(item, topology)).toList();

    return Dashboard(name: layout.name, children: children);
  }

  Widget _fromLayouts(HashMap<int, DashboardLayout> layouts) {
    final topologyAsync = ref.watch(topologyServiceProvider);
    final selected = ref.watch(dashboardSelectionProvider);

    return topologyAsync.when(
      error: (e, _) => RetryIndicator(onRetry: () async => onRetry, isLoading: false, error: e),
      loading: () => RetryIndicator(onRetry: () async => onRetry , isLoading: true),
      data: (topology) => _fromLayoutsWithTopology(topology, layouts, selected),
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