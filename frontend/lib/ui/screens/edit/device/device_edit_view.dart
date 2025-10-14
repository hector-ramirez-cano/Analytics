import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
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

  // Callbacks that show a dialog
  void onRequestedDelete()  { ref.read(itemEditSelectionProvider.notifier).onRequestDeletion(); displayDeleteConfirmDialog(context, ref); }
  void onConfirmRestore ()  { ref.read(itemEditSelectionProvider.notifier).onRestoreSelected(); }

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