import 'package:flutter/material.dart';

enum SideNavItem {
  listado (Icons.segment , 'Listado' ),
  search  (Icons.search  , 'Search'  ),
  settings(Icons.settings, 'Settings');

  final IconData icon;
  final String   label;

  const SideNavItem(this.icon, this.label);

  static List<IconData> get icons {
    return SideNavItem.values.map((item) => item.icon).toList();
  }

  static List<String> get labels {
    return SideNavItem.values.map((item) => item.label).toList();
  }

  static int get length {
    return SideNavItem.values.length;
  }
}
