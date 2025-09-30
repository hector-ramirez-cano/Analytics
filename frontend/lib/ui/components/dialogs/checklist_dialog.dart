
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/ui/components/dialogs/selection_dialog.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

class ChecklistDialog<T> extends SelectionDialog<T>{

  ChecklistDialog({
    required super.options,
    required super.onChanged,
    required super.onClose,
    required super.isSelectedFn,
    super.selectorType = ListSelectorType.checkbox,
    super.onTristateToggle,
  });

  @override
  Future show(BuildContext context) {
    BuildContext? dialogContext;
    
    toText(t) => t.toString();
    localOnClose() {
      if (dialogContext != null && dialogContext!.mounted) { 
        Logger().d("closed dialog!");
        Navigator.pop(dialogContext!);
        onClose();
      }
    }

    final dialog = Consumer(builder:(context, ref, child) {
      ref.watch(dialogRebuildProvider);

      return Dialog(
        child: ListSelector<T>(
          options: options,
          selectorType: selectorType,
          isSelectedFn: isSelectedFn,
          onChanged: onChanged,
          onClose: localOnClose,
          toText: toText,
          onTristateToggle: onTristateToggle,
        ),
      );
      
      
    },);
    
    return showDialog(context: context, builder: (context) {
      dialogContext = context;
      return dialog;
    });
  }
}