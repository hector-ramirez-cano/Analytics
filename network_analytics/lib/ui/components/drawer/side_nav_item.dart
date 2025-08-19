import 'package:flutter/material.dart';

enum SideNavItem {
  listado (Icons.segment   , 'Listado' , false, true),
  search  (Icons.search    , 'Search'  , false, true),
  charts  (Icons.area_chart, 'Gráficas', false, false),
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
}
