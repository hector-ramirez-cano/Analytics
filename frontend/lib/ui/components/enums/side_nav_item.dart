import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';

enum SideNavItem {
  items   (Icons.segment   , 'Listado' , false, true),
  search  (Icons.search    , 'Search'  , false, true),
  charts  (Icons.area_chart, 'Gráficas', false, true),
  settings(Icons.settings  , 'Settings', true , false);

  final IconData icon;
  final String   label;
  final bool     bottom;
  final bool     hasDrawer;

  const SideNavItem(this.icon, this.label, this.bottom, this.hasDrawer);

  static List<IconData> get icons {
    return SideNavItem.values.map((item) => item.icon).toList();
  }

  static List<String> get labels {
    return SideNavItem.values.map((item) => item.label).toList();
  }

  static List<SideNavItem> get bottomItems {
    return SideNavItem.values.where((item) => item.bottom).toList();
  }

  static List<SideNavItem> get topItems {
    return SideNavItem.values.where((item) => !item.bottom).toList();
  }

  static int get length {
    return SideNavItem.values.length;
  }

  WorkplaceScreen getSelectedScreen() {
    WorkplaceScreen selectedScreen;
    switch (this) {
      case SideNavItem.items:
      case SideNavItem.search:
        selectedScreen = WorkplaceScreen.canvas;

      case SideNavItem.charts:
        selectedScreen = WorkplaceScreen.charts;

      case SideNavItem.settings:
        selectedScreen = WorkplaceScreen.settings;

      // keeping this in case new items are added
      // ignore: unreachable_switch_default
      default:
        Logger().e("[ERROR]Selected Screen is null. This indicates a missing case for ContentArea Switching upon sidenav interaction!");
        throw Exception("[ERROR]Selected Screen is null. This indicates a missing case for ContentArea Switching upon sidenav interaction!");
    }

    return selectedScreen;
  }
}
