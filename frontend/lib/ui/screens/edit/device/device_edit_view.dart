import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/commons/checkbox_select_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:network_analytics/ui/screens/edit/device/device_general_settings.dart';
import 'package:network_analytics/ui/screens/edit/device/device_group_settings.dart';
import 'package:network_analytics/ui/screens/edit/device/device_link_settings.dart';
import 'package:network_analytics/ui/screens/edit/device/geo_select_dialog.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends ConsumerStatefulWidget {
  final Topology topology;

  const DeviceEditView({
    super.key,
    required this.topology,
  });

  @override
  ConsumerState<DeviceEditView> createState() => _DeviceEditViewState();
}

class _DeviceEditViewState extends ConsumerState<DeviceEditView> {


  Widget _buildValueSelectionInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.watch(itemEditSelectionNotifier.notifier); 
    bool enabled = itemEditSelection.editingDeviceMetrics || itemEditSelection.editingDeviceMetadata;

    if (!enabled) { return SizedBox.shrink(); }

    var pool = itemEditSelection.editingDeviceMetrics ? notifier.device.requestedMetrics : notifier.device.requestedMetadata;

    onChanged (option, state) => {
      if (itemEditSelection.editingDeviceMetrics) {
        notifier.onChangeSelectedMetric(option, state)
      } else if (itemEditSelection.editingDeviceMetadata) {
        notifier.onChangeSelectedMetadata(option, state)
      } else {
        throw Exception("Unreachable code reached! Logic is faulty!")
      }
    }; 
    isSelected (option) => pool.contains(option);
    onClose () => notifier.set(editingDeviceMetadata: false, editingDeviceMetrics: false); 
    toText(option) => option as String;
    var options = notifier.device.availableValues;

    return CheckboxSelectDialog(options: options, isSelected: isSelected, onChanged: onChanged, onClose: onClose, toText: toText,);
  }

  Widget _buildGeoInputDialog() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    bool enabled = itemEditSelection.editingDeviceGeoPosition;

    if (!enabled) { return SizedBox.shrink(); }

    onClose() => ref.read(itemEditSelectionNotifier.notifier).set(editingDeviceGeoPosition: false);

    return GeoSelectDialog(onClose: onClose);
  }

  Widget _buildConfigurationPage() {
    return Column(
      children: [ Expanded(child: SettingsList( sections: [
              CustomSettingsSection(child: DeviceGeneralSettings(widget.topology,)),
              CustomSettingsSection(child: DeviceLinkSettings   (widget.topology)),
              CustomSettingsSection(child: DeviceGroupSettings  (widget.topology)),
            ],
          ),
        ) ,
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        _buildConfigurationPage(),
        _buildValueSelectionInput(),
        _buildGeoInputDialog(),
      ],
    );
  }
}