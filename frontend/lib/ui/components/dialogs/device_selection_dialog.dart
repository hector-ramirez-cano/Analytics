import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/ui/components/dialogs/selection_dialog.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

class DeviceSelectionDialog extends SelectionDialog<Device>{

  const DeviceSelectionDialog({
    required super.options,
    required super.selectorType,
    required super.onChanged,
    required super.onClose,
    required super.isSelectedFn,
    required super.isAvailable,
    super.onTristateToggle,
  });
  
  @override
  Future show(BuildContext context) {
    BuildContext? dialogContext;
    
    toText(option) => (option as Device).name;
    void localOnClose() { 
      if (dialogContext != null && dialogContext!.mounted) { 
        Logger().d("closed dialog!");
        Navigator.pop(dialogContext!);
        onClose();
      } 
    }

    final dialog = Dialog(
      child: ListSelector<Device>(
        options: options,
        selectorType: selectorType,
        isSelectedFn: isSelectedFn,
        onChanged: onChanged,
        onClose: localOnClose,
        toText: toText,
        isAvailable: isAvailable,
        onTristateToggle: onTristateToggle,
      ),
    );
    
    return showDialog(context: context, builder: (context) {
      dialogContext = context;
      return dialog;
    });
  }
}