import 'package:aegis/services/realtime/backend_health_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/item_edit_selection_notifier.dart';
import 'package:aegis/ui/components/dialogs/option_dialog.dart';
import 'package:aegis/ui/components/universal_detector.dart';

const Color addedItemColor = Colors.green;
const Color deletedItemColor = Color.fromRGBO(233, 104, 95, 1);

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
  const TextStyle saveLabelStyle = TextStyle(color: Colors.white);

  final notifier = ref.watch(itemEditSelectionProvider.notifier);
  final enabled = ref.watch(backendHealthServiceProvider).when(
    data: (d) => d.backendConfigurable,
    error: (_, _) => false,
    loading: () => false
  );
  ButtonStyle saveStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    disabledMouseCursor: enabled ? null /*default behavior*/  : SystemMouseCursors.forbidden,
  );

  onCancel() => {
    notifier.discard()
  };
  onSave() async {
    final result = await ref.read(itemEditSelectionProvider.notifier).apply();

    if (ref.context.mounted) {
      if (result) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text("Se guardaron los cambios!"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar los cambios! Revise los logs"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            backgroundColor: const Color.fromARGB(255, 133, 43, 43),
          ),
        );
      }
    }
  }

  var cancelButton = ElevatedButton(
    onPressed: () => onCancel(),
    child: const Text("Descartar"),
  );

  var saveButton = ElevatedButton(
    onPressed: (notifier.hasChanges && enabled) ? onSave : null,
    style: saveStyle,

    child: Text(
      enabled ? "Guardar cambios" : "Modo sólo lectura",
      style: saveLabelStyle,
    ),
  );

  return SizedBox(
    height: 80,
    child: Stack(children: [
        Positioned(
          right: 16, bottom: 16,
          child: Row(children: [
              if (enabled) 
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

void displayDeleteConfirmDialog(BuildContext context, WidgetRef ref,) {
    void onConfirmedDelete()   => ref.read(itemEditSelectionProvider.notifier).onDeleteSelected();
    void onCancelDelete()      => ref.read(itemEditSelectionProvider.notifier).set(requestedConfirmDeletion: false);

    final itemSelection = ref.read(itemEditSelectionProvider);

    bool showConfirmDialog = itemSelection.confirmDeletion;

    if (!showConfirmDialog) { return; }

    OptionDialog(
      dialogType: OptionDialogType.cancelDelete,
      title: Text("Confirmar acción"),
      confirmMessage: Text("(Los cambios no serán apliacados todavía)"),
      onCancel: onCancelDelete,
      onDelete: onConfirmedDelete,
    ).show(context);
  }