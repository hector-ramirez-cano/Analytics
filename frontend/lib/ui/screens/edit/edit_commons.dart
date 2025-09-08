import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';

class EditTextField extends StatelessWidget {
  final String initialText;
  final bool showEditIcon;
  final bool enabled;
  final Function(String) onContentEdit;
  final VoidCallback onEditToggle;
  final TextEditingController? controller;
  
  const EditTextField({
    super.key,
    required this.enabled,
    required this.initialText,
    required this.onContentEdit,
    required this.onEditToggle,

    this.controller,
    this.showEditIcon = false,
  });

  Widget makeTrailingInput() {
    return TextField(
      enabled: enabled,
      controller: controller ?? TextEditingController(text: initialText),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: onContentEdit,
    );
  }

  Widget _makeTrailingIcon() {
    return 
      UniversalDetector(
        setCursor: () => SystemMouseCursors.click,
        onTapUp: (_) => onEditToggle(),
        child: Icon(
              Icons.edit,
              size: 20,
              color: Colors.black54,
            )
      ); 
  }

  Widget makeTrailing(Widget child) {
    return SizedBox(
      width: 220, // adjust to accommodate icon
      child: Row(
        children: [
          Expanded(
            child: child,
          ),
          const SizedBox(width: 4),
          showEditIcon ? 
            _makeTrailingIcon()
            : SizedBox.shrink()
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    var input = makeTrailingInput();

    return makeTrailing(input);
  }

}


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

Widget makeTrailing(Widget child, VoidCallback onEdit, {bool showEditIcon = true, double width = 220}) {
  return SizedBox(
    width: width,
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

Widget makeFooter(WidgetRef ref, Topology topology) {
  ButtonStyle saveStyle = ElevatedButton.styleFrom(backgroundColor: Colors.blue,);
  const TextStyle saveLabelStyle = TextStyle(color: Colors.white);

  final notifier = ref.read(itemEditSelectionNotifier.notifier);

  onCancel() => {
    notifier.discard()
  };
  onSave() => {}; // TODO: Funcionality

  var cancelButton = ElevatedButton(
    onPressed: () => onCancel(),
    child: const Text("Descartar"),
  );

  var saveButton = ElevatedButton(
    onPressed: notifier.hasChanges ? onSave : null ,
    style: saveStyle,

    child: const Text("Guardar cambios", style: saveLabelStyle,),
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
