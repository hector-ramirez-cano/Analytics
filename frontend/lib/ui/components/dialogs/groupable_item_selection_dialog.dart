import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/ui/components/dialogs/selection_dialog.dart';
import 'package:network_analytics/ui/components/list_selector.dart';


Icon? defaultIcons(dynamic item) {
  if (item is Device) { return Icon(Icons.dns); }
  if (item is Group ) { return Icon(Icons.folder); }
  return null;
}

Widget? defaultSubtitle(dynamic _) => null;

class GroupableItemSelectionDialog extends SelectionDialog<GroupableItem>{

  const GroupableItemSelectionDialog({
    required super.options,
    required super.selectorType,
    required super.onChanged,
    required super.onClose,
    required super.isSelectedFn,
    required super.isAvailable,
    super.leadingIconBuilder = defaultIcons,
    super.subtitleBuilder = defaultSubtitle,
    super.onTristateToggle,
  });
  
  @override
  Future show(BuildContext context) {
    BuildContext? dialogContext;
    
    toText(option) => (option as GroupableItem).name;
    void localOnClose() { 
      if (dialogContext != null && dialogContext!.mounted) { 
        Logger().d("closed dialog!");
        Navigator.pop(dialogContext!);
        onClose();
      } 
    }

    final dialog = Dialog(
      child: ListSelector<GroupableItem>(
        options: options,
        selectorType: selectorType,
        isSelectedFn: isSelectedFn,
        onChanged: onChanged,
        onClose: localOnClose,
        toText: toText,
        isAvailable: isAvailable,
        onTristateToggle: onTristateToggle,
        leadingIconBuilder: leadingIconBuilder,
        subtitleBuilder: subtitleBuilder,
      ),
    );
    
    return showDialog(context: context, builder: (context) {
      dialogContext = context;
      return dialog;
    });
  }
}