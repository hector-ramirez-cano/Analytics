import 'package:flutter/material.dart';

// ignore: unused_import
import 'package:logger/web.dart';

import 'package:network_analytics/ui/components/drawer/side_nav_item.dart';
import 'package:network_analytics/theme/app_colors.dart';

class SideNav extends StatelessWidget {
  final SideNavItem? selectedPanel;
  final void Function(SideNavItem selectedPanel) onPressed;

  const SideNav({
    super.key,
    required this.selectedPanel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = [];
    widgets.addAll(List.generate(SideNavItem.topItems.length, (index) => _buildChild(SideNavItem.topItems[index])));
    widgets.add(Spacer());
    widgets.addAll(List.generate(SideNavItem.bottomItems.length, (index) => _buildChild(SideNavItem.bottomItems[index])));

    // Logger().d("Top =${SideNavItem.topItems}, Bottom=${SideNavItem.bottomItems}");

    return Container(
      width: 60,
      color: AppColors.sidebarColor,
      child: Column(
        children: widgets
      ),
    );
  }

  Widget _buildChild(SideNavItem panel) {
    final isSelected = panel == selectedPanel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IconButton(
        icon: Icon(panel.icon),
        tooltip: panel.label,
        color: isSelected
            ? AppColors.selectedIconColor
            : Colors.white,
        onPressed: () => onPressed(panel),
      ),
    );
  }
}
