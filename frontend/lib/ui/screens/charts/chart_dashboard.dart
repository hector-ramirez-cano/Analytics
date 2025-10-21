import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/dashboard_service.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:network_analytics/ui/components/dashboard.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/charts/chart.dart';

class ChartDashboard extends ConsumerStatefulWidget {
  const ChartDashboard({super.key});

  @override
  ConsumerState<ChartDashboard> createState() => _ChartDashboardState();
}

class _ChartDashboardState extends ConsumerState<ChartDashboard> {

  List<int> rows = [0 ,1];
  List<int> rowSpans = [1, 1];
  List<int> columns = [0, 0];
  List<int> columnSpans = [2, 1];

  void onRetry() async => ref.invalidate(websocketServiceProvider);

  DashboardWidget _widgetFromDashboardItem(DashboardItem item) {
    return DashboardWidget(item.rowStart, item.rowSpan, item.columnStart, item.columnSpan, child: LineChartSample2());
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