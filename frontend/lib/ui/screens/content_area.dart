import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';
import 'package:network_analytics/ui/screens/canvas/topology_tab_view.dart';
import 'package:network_analytics/ui/screens/charts/chart.dart';
import 'package:network_analytics/ui/screens/settings/settings.dart';

class ContentArea extends StatelessWidget {
  final WorkplaceScreen screen;

  const ContentArea({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    switch (screen) {
      case WorkplaceScreen.canvas:
        return TopologyTabView();

      case WorkplaceScreen.charts:
        return LineChartSample2();

      case WorkplaceScreen.settings:
        return SettingsScreen();

      // ignore: unreachable_switch_default
      default:
        Logger().w("[ERROR]Displaying screen undefined on WorkplaceScreen!");
        return Text("[ERROR]Displaying screen undefined on WorkplaceScreen!");
    }
  }
}
