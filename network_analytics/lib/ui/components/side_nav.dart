import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/drawer/side_nav_item.dart';
import '../../theme/app_colors.dart';

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
    return Container(
      width: 60,
      color: AppColors.sidebarColor,
      child: Column(
        children: List.generate(SideNavItem.length, (index) => _buildChild(SideNavItem.values[index])),
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
