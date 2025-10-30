import 'package:flutter/material.dart';

class ChipTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onClick;

  const ChipTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onClick
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
        label: Text(label),
        onPressed: onClick,
        tooltip: "",
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(1),
        ),
    );
  }

}