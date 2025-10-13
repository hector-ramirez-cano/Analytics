import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
import 'package:network_analytics/ui/components/dialogs/option_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:network_analytics/ui/screens/edit/device/device_general_settings.dart';
import 'package:network_analytics/ui/screens/edit/device/device_group_settings.dart';
import 'package:network_analytics/ui/screens/edit/device/device_link_settings.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends ConsumerStatefulWidget {
  final Topology topology;
  final bool showDeleteButton;

  const DeviceEditView({
    super.key,
    required this.topology,
    required this.showDeleteButton,
  });

  @override
  ConsumerState<DeviceEditView> createState() => _DeviceEditViewState();
}

class _DeviceEditViewState extends ConsumerState<DeviceEditView> {

  void onCancelDelete()      => ref.read(itemEditSelectionProvider.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()   => ref.read(itemEditSelectionProvider.notifier).onDeleteSelected();
  void onConfirmRestore()    => ref.read(itemEditSelectionProvider.notifier).onRestoreSelected();
  
  // Callbacks that show a dialog
  void onRequestedDelete()   { ref.read(itemEditSelectionProvider.notifier).onRequestDeletion(); _displayDeleteConfirmDialog(); }

  void _displayDeleteConfirmDialog() {
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

  Widget _buildConfigurationPage() {

    final sections = [
              CustomSettingsSection(child: DeviceGeneralSettings(widget.topology,)),
              CustomSettingsSection(child: DeviceLinkSettings   (widget.topology)),
              CustomSettingsSection(child: DeviceGroupSettings  (widget.topology)),
              
            ];

    if (widget.showDeleteButton) {
      sections.add(CustomSettingsSection(child: DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore)));
    }

    return Column(
      children: [ Expanded(child: SettingsList( sections: sections,
          ),
        ) ,
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildConfigurationPage();
  }
}