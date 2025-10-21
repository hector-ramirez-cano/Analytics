import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';
import 'package:network_analytics/models/enums/workplace_screen.dart';
import 'package:network_analytics/ui/screens/alerts/alert_viewer.dart';
import 'package:network_analytics/ui/screens/canvas/topology_tab_view.dart';
import 'package:network_analytics/ui/screens/charts/chart_dashboard.dart';
import 'package:network_analytics/ui/screens/edit/editor_view.dart';
import 'package:network_analytics/ui/screens/settings/settings.dart';
import 'package:network_analytics/ui/screens/syslog/syslog_viewer.dart';

class ContentArea extends StatelessWidget {

  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: 
      (context, ref, child) {
        final item = ref.watch(sideNavSelectionProvider);
        final screen = item?.getSelectedScreen();

        switch (screen) {
          case WorkplaceScreen.canvas:
            return TopologyTabView();

          case WorkplaceScreen.charts:
            return ChartDashboard();

          case WorkplaceScreen.settings:
            return SettingsScreen();

          case WorkplaceScreen.edit:
            return ItemEditView();

          case WorkplaceScreen.syslog:
            return SyslogViewer();

          case WorkplaceScreen.alerts:
            return AlertViewer();

          case null:
            Logger().w("Created content area for undefined WorkplaceScreen");
            return Text("Nobody here but us, chickens!");
        }
      }
    );
    
  }
}
