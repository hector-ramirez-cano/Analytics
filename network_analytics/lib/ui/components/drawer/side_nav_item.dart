import 'package:flutter/material.dart';

enum SideNavItem {
  listado (Icons.segment , 'Listado' , false),
  search  (Icons.search  , 'Search'  , false),
  settings(Icons.settings, 'Settings', true);

  final IconData icon;
  final String   label;
  final bool     bottom;

  const SideNavItem(this.icon, this.label, this.bottom);

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
