import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';

const Color modifiedColor = Colors.green;

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
