import 'package:flutter/material.dart';

class ClosableChipTab extends StatelessWidget {
  final String label;
  final bool selected;

  const ClosableChipTab({
    super.key,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.grey[850] : Colors.grey[300],
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top stripe
          Container(
            height: 3,
            width: double.infinity, // make it span the width of the tab
            color: selected ? Colors.blue : Colors.transparent,
          ),
          // Label + X
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.close,
                  size: 16,
                  color: selected ? Colors.white : Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
