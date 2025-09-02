import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';

Widget _makeTrailingIcon(VoidCallback onEdit) {
  return 
    UniversalDetector(
      setCursor: () => SystemMouseCursors.click,
      onTapUp: (_) => onEdit(),
      child: Icon(
            Icons.edit,
            size: 20,
            color: Colors.black54,
          )
    ); 
}

Widget makeTrailing(Widget child, VoidCallback onEdit, {bool showEditIcon = true}) {
  return SizedBox(
    width: 220, // adjust to accommodate icon
    child: Row(
      children: [
        Expanded(
          child: child,
        ),
        const SizedBox(width: 4),
        showEditIcon ? 
          _makeTrailingIcon(onEdit)
          : SizedBox.shrink()
      ],
    ),
  );
}

Widget makeTrailingInput(String text, bool enabled) {
  return TextField(
    enabled: enabled,
    controller: TextEditingController(text: text),
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    onChanged: (val) {
      // handle value change
    },
  );
}



Widget makeFooter() {
  ButtonStyle saveStyle = ElevatedButton.styleFrom(backgroundColor: Colors.blue,);
  const TextStyle saveLabelStyle = TextStyle(color: Colors.white);

  onCancel() => {};
  onSave() => {};

  var cancelButton = ElevatedButton(
    onPressed: () => onCancel(),
    child: const Text("Cancel"),
  );

  var saveButton = ElevatedButton(
    onPressed: () => onSave,
    style: saveStyle,
    child: const Text("Save", style: saveLabelStyle,),
  );

  return SizedBox(
    height: 80,
    child: Stack(children: [
        Positioned(
          right: 16, bottom: 16,
          child: Row(children: [
              cancelButton,
              const SizedBox(width: 16),
              saveButton,
            ],
          ),
        ),
      ],
    ),
  );
}
