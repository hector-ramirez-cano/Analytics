import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/item_edit_selection_notifier.dart';
import 'package:settings_ui/settings_ui.dart';

class DeleteSection extends StatelessWidget {
  final Function() onRestore;
  final Function() onDelete;

  const DeleteSection({
    super.key,
    required this.onDelete,
    required this.onRestore,
  });
  
  SettingsSection _makeDeleteSection(WidgetRef ref) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    bool deleted = notifier.isDeleted(notifier.selected);
    String label = deleted ? "Restaurar" : "Eliminar";
    var onAction = deleted ? onRestore : onDelete;

    resolveColor (states) {
      if (deleted) {
        if (states.contains(WidgetState.hovered)) {
          return const Color.fromRGBO(111, 170, 88, 1);
        } 
        return Colors.grey;
      }

      if (states.contains(WidgetState.hovered)) {
        return const Color.fromRGBO(226, 71, 71, 1);
      } 
      return Colors.grey;
    }

    return SettingsSection(
      title: Text(""), tiles: [
        SettingsTile(title: SizedBox(
          width: double.infinity, 
          child: ElevatedButton(
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(Colors.white),
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(resolveColor)
            ),
            onPressed: onAction,
            child: Text(label, ),
          ),))
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (_, ref, _) {
      return _makeDeleteSection(ref);
    });
  }

  
}