import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SideNav extends StatelessWidget {
  final int? selectedIndex;
  final List<IconData> icons;
  final List<String> labels;
  final void Function(int index) onPressed;

  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.icons,
    required this.labels,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      color: AppColors.sidebarColor,
      child: Column(
        children: List.generate(icons.length, (index) => _buildChild(index)),
      ),
    );
  }

  Widget _buildChild(int index) {
    final isSelected = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IconButton(
        icon: Icon(icons[index]),
        tooltip: labels[index],
        color: isSelected
            ? AppColors.selectedIconColor
            : Colors.white,
        onPressed: () => onPressed(index),
      ),
    );
  }
}
