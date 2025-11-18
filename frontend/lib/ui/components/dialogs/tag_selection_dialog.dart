import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:aegis/ui/components/dialogs/selection_dialog.dart';
import 'package:aegis/ui/components/list_selector.dart';


Widget? _emptyDisplayTrailing(dynamic option) { return null; }
class TagSelectionDialog extends SelectionDialog<String>{

  final Widget? Function(dynamic option) onDisplayTrailing;

  const TagSelectionDialog({
    required super.options,
    required super.selectorType,
    required super.onChanged,
    required super.onClose,
    required super.isSelectedFn,
    required super.isAvailable,
    super.onTristateToggle,
    super.subtitleBuilder,
    this.onDisplayTrailing = _emptyDisplayTrailing,
    
  });
  
  @override
  Future show(BuildContext context) {
    BuildContext? dialogContext;
    
    toText(option) => (option as String);
    void localOnClose() { 
      if (dialogContext != null && dialogContext!.mounted) { 
        Logger().d("closed dialog!");
        Navigator.pop(dialogContext!);
        onClose();
      } 
    }

    final dialog = Dialog(
      child: ListSelector<String>(
        options: options,
        selectorType: selectorType,
        isSelectedFn: isSelectedFn,
        onChanged: onChanged,
        onClose: localOnClose,
        toText: toText,
        onTristateToggle: onTristateToggle,
        isAvailable: isAvailable,
        onDisplayTrailing: onDisplayTrailing,
      ),
    );
    
    return showDialog(context: context, builder: (context) {
      dialogContext = context;
      return dialog;
    });
  }
}