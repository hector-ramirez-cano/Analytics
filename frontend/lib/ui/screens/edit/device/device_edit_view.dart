import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:network_analytics/models/data_sources.dart';
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

  void onGeoPositionChanged(LatLng p) => ref.read(itemEditSelectionNotifier.notifier).onChangeDeviceGeoPosition(p);

  Widget _buildValueSelectionInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notif = ref.watch(itemEditSelectionNotifier.notifier); 
    bool metrics = itemEditSelection.editingDeviceMetrics;
    bool metadata = itemEditSelection.editingDeviceMetadata;
    bool datasources = itemEditSelection.editingDeviceDataSources;

    bool enabled = metrics || metadata || datasources;

    if (!enabled) { return SizedBox.shrink(); }

    Set<String> selectedOptions;
    Set<String> options;
    if (metrics)     { selectedOptions = notif.device.requestedMetrics   ; options = notif.device.availableValues; }
    if (metadata)    { selectedOptions = notif.device.requestedMetadata  ; options = notif.device.availableValues; }
    if (datasources) { selectedOptions = notif.device.dataSources        ; options = DataSources.values.map((i) => i.name).toSet(); }
    else { return SizedBox.shrink(); }

    onChanged (option, state) => {
      if      (metrics)  { notif.onChangeSelectedMetric(option, state) } 
      else if (metadata) { notif.onChangeSelectedMetadata(option, state) }
      else if (datasources) {notif.onChangeSelectedDatasource(option, state) }
      else {
        throw Exception("Unreachable code reached! Logic is faulty!")
      }
    }; 
    isSelected (option) => selectedOptions.contains(option);
    onClose () => notif.set(editingDeviceMetadata: false, editingDeviceMetrics: false, editingDeviceDataSources: false); 
    toText(option) => option as String;

    return CheckboxSelectDialog(options: options, isSelected: isSelected, onChanged: onChanged, onClose: onClose, toText: toText,);
  }

  Widget _buildGeoInputDialog() {
    final itemEditSelection = ref.read(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier); 
    bool enabled = itemEditSelection.editingDeviceGeoPosition;
    LatLng initial = notifier.device.geoPosition;

    if (!enabled) { return SizedBox.shrink(); }

    onClose() => ref.read(itemEditSelectionNotifier.notifier).set(editingDeviceGeoPosition: false);

    return GeoSelectDialog(
      onClose: onClose,
      initialPosition: initial,
      onSelect: onGeoPositionChanged,
    );
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