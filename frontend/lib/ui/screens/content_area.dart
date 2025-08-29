import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';
import 'package:network_analytics/ui/screens/canvas/topology_tab_view.dart';
import 'package:network_analytics/ui/screens/charts/chart.dart';
import 'package:network_analytics/ui/screens/settings/settings.dart';

class ContentArea extends StatelessWidget {

  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: 
      (context, ref, child) {
        final SideNavSelection item = ref.watch(screenSelectionNotifier);
        final screen = item.selected.getSelectedScreen();

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
    );
    
  }
}
