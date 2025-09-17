import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';

enum NavigationRailItem {
  canvas   (Icons.segment   , 'Topología'      , bottom: false, hasDrawer: true ),
  search   (Icons.search    , 'Búsqueda'       , bottom: false, hasDrawer: true ),
  charts   (Icons.area_chart, 'Gráficas'       , bottom: false, hasDrawer: true ),
  edit     (Icons.edit      , "Editar datos"   , bottom: true , hasDrawer: true ),
  settings (Icons.settings  , 'Configuraciones', bottom: true , hasDrawer: false);

  final IconData icon;
  final String   label;
  final bool     bottom;
  final bool     hasDrawer;

  const NavigationRailItem(this.icon, this.label, {required this.bottom, required this.hasDrawer});

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
    WorkplaceScreen selectedScreen;
    switch (this) {
      case NavigationRailItem.canvas:
      case NavigationRailItem.search:
        selectedScreen = WorkplaceScreen.canvas;

      case NavigationRailItem.charts:
        selectedScreen = WorkplaceScreen.charts;

      case NavigationRailItem.settings:
        selectedScreen = WorkplaceScreen.settings;

      case NavigationRailItem.edit:
        selectedScreen = WorkplaceScreen.edit;

      // keeping this in case new items are added
      // ignore: unreachable_switch_default
      default:
        Logger().e("[ERROR]Selected Screen is null. This indicates a missing case for ContentArea Switching upon sidenav interaction!");
        throw Exception("[ERROR]Selected Screen is null. This indicates a missing case for ContentArea Switching upon sidenav interaction!");
    }

    return selectedScreen;
  }
}
