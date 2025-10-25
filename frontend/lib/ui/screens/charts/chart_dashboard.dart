import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/charts/metadata_polling_definition.dart';
import 'package:network_analytics/models/charts/metric_polling_definition.dart';
import 'package:network_analytics/services/dashboard_service.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:network_analytics/ui/components/dashboard.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/charts/metadata_label.dart';
import 'package:network_analytics/ui/screens/charts/metric_line_chart.dart';

class ChartDashboard extends ConsumerStatefulWidget {
  const ChartDashboard({super.key});

  @override
  ConsumerState<ChartDashboard> createState() => _ChartDashboardState();
}

class _ChartDashboardState extends ConsumerState<ChartDashboard> {

  void onRetry() async => ref.invalidate(websocketServiceProvider);

  DashboardWidget _widgetFromDashboardItem(DashboardItem item) {

    final Widget child;
    if (item.definition is MetadataPollingDefinition) {
      child = MetadataLabel(definition: item.definition as MetadataPollingDefinition);
    }
    else if (item.definition is MetricPollingDefinition) {
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

  Dashboard _fromLayouts(List<DashboardLayout> layouts) {
    if (layouts.isEmpty) { return Dashboard(name: "", children: []); }

    final layout = layouts.first;

    final children = layout.items.map((item) => _widgetFromDashboardItem(item)).toList();

    return Dashboard(name: layout.name, children: children);
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