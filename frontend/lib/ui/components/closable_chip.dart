import 'package:flutter/material.dart';

class ClosableChipTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onClose;
  final VoidCallback onClick;

  const ClosableChipTab({
    super.key,
    required this.label,
    required this.onClose,
    required this.onClick,
    required this.selected,
  });
  
  @override
  Widget build(BuildContext context) {
    var backgroundColor = selected ? Colors.grey[800] : Colors.grey[200];
    var textColor = selected ? Colors.white : Colors.black;

    return InputChip(
        label: 
          Text(label),
        onDeleted: () => onClose(),
        onPressed: () => onClick(),
        deleteIcon: const Icon(Icons.close, size: 18),
        deleteIconColor: Colors.grey[400],
        backgroundColor: backgroundColor,
        tooltip: "",
        deleteButtonTooltipMessage: "",
        labelStyle: TextStyle(color: textColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(1),
        ),
    );
  }

}

