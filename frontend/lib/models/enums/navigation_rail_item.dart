import 'package:flutter/material.dart';
import 'package:aegis/models/enums/workplace_screen.dart';

enum NavigationRailItem {
  canvas   (Icons.segment       , 'Topología'      , bottom: false, hasDrawer: true , screen: WorkplaceScreen.canvas  ),
  charts   (Icons.area_chart    , 'Gráficas'       , bottom: false, hasDrawer: true , screen: WorkplaceScreen.charts  ),
  syslog   (Icons.terminal      , 'Syslog'         , bottom: false, hasDrawer: false, screen: WorkplaceScreen.syslog  ),
  alerts   (Icons.notifications , 'Alertas'        , bottom: false, hasDrawer: false, screen: WorkplaceScreen.alerts  ),
  edit     (Icons.edit          , "Editar datos"   , bottom: true , hasDrawer: true , screen: WorkplaceScreen.edit    ),
  settings (Icons.settings      , 'Configuraciones', bottom: true , hasDrawer: false, screen: WorkplaceScreen.settings);

  final IconData icon;
  final String   label;
  final bool     bottom;
  final bool     hasDrawer;
  final WorkplaceScreen screen;

  const NavigationRailItem(this.icon, this.label, {required this.bottom, required this.hasDrawer, required this.screen});

  static List<IconData> get icons {
    return NavigationRailItem.values.map((item) => item.icon).toList();
  }

  static List<String> get labels {
    return NavigationRailItem.values.map((item) => item.label).toList();
  }

  static List<NavigationRailItem> get bottomItems {
    return NavigationRailItem.values.where((item) => item.bottom).toList();
  }

  static List<NavigationRailItem> get topItems {
    return NavigationRailItem.values.where((item) => !item.bottom).toList();
  }

  static int get length {
    return NavigationRailItem.values.length;
  }

  static List<NavigationRailDestination> get destinations {
    return values.map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))).toList();
  }

  static List<NavigationRailDestination> get topDestinations {
    return topItems.map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))).toList();
  }

  static List<NavigationRailDestination> get bottomDestinations {
    return bottomItems.map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))).toList();
  }

  WorkplaceScreen getSelectedScreen() {
    return screen;
  }
}
