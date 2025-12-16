import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:aegis/services/screen_selection_notifier.dart';
import 'package:aegis/models/enums/workplace_screen.dart';
import 'package:aegis/ui/screens/alerts/alert_viewer.dart';
import 'package:aegis/ui/screens/canvas/topology_tab_view.dart';
import 'package:aegis/ui/screens/charts/chart_dashboard.dart';
import 'package:aegis/ui/screens/edit/editor_view.dart';
import 'package:aegis/ui/screens/syslog/syslog_viewer.dart';

class ContentArea extends StatelessWidget {

  static const _topologyTabView = TopologyTabView(key: ValueKey("Screen_TopologyTabView"));
  static const _chartDashboard = ChartDashboard(key: ValueKey("Screen_ChartDashboard"));
  static const _itemEditView = ItemEditView(key: ValueKey("Screen_ItemEditView"));
  static const _syslogViewer = SyslogViewer(key: ValueKey("Screen_SyslogViewer"));
  static const _alertViewer = AlertViewer(key: ValueKey("Screen_AlertViewer"));

  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: 
      (context, ref, child) {
        final item = ref.watch(sideNavSelectionProvider);
        final screen = item?.getSelectedScreen();

        switch (screen) {
          case WorkplaceScreen.canvas:
            return _topologyTabView;

          case WorkplaceScreen.charts:
            return _chartDashboard; 

          // case WorkplaceScreen.settings:
          //   return SettingsScreen(key: ValueKey("Screen_SettingsScreen"));

          case WorkplaceScreen.edit:
            return _itemEditView; 

          case WorkplaceScreen.syslog:
            return _syslogViewer; 

          case WorkplaceScreen.alerts:
            return _alertViewer; 

          case null:
            Logger().w("Created content area for undefined WorkplaceScreen");
            return Text("Nobody here but us, chickens!");
        }
      }
    );
    
  }
}
