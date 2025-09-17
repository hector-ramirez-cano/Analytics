import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:network_analytics/models/data_sources.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
import 'package:network_analytics/ui/screens/edit/commons/option_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/select_dialog.dart';
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
  void onRequestedDelete()   => ref.read(itemEditSelectionNotifier.notifier).onRequestDeletion();
  void onCancelDelete()      => ref.read(itemEditSelectionNotifier.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()   => ref.read(itemEditSelectionNotifier.notifier).onDeleteSelected();
  void onConfirmRestore()    => ref.read(itemEditSelectionNotifier.notifier).onRestoreSelected();

  Widget _buildSelectionDialog() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notif = ref.watch(itemEditSelectionNotifier.notifier); 
    bool metrics = itemEditSelection.editingDeviceMetrics;
    bool metadata = itemEditSelection.editingDeviceMetadata;
    bool datasources = itemEditSelection.editingDeviceDataSources;

    bool enabled = metrics || metadata || datasources;

    if (!enabled) { return SizedBox.shrink(); }

    Set<String> selectedOptions;
    Set<String> options;
    if      (metrics)     { selectedOptions = notif.device.requestedMetrics   ; options = notif.device.availableValues; }
    else if (metadata)    { selectedOptions = notif.device.requestedMetadata  ; options = notif.device.availableValues; }
    else if (datasources) { selectedOptions = notif.device.dataSources        ; options = DataSources.values.map((i) => i.name).toSet(); }
    else { return SizedBox.shrink(); }

    onChanged (option, state) => {
      if      (metrics)  { notif.onChangeSelectedMetric(option, state) } 
      else if (metadata) { notif.onChangeSelectedMetadata(option, state) }
      else if (datasources) {notif.onChangeSelectedDatasource(option, state) }
      else {
        throw Exception("Unreachable code reached! Logic is faulty!")
      }
    }; 
    isSelectedFn (option) => selectedOptions.contains(option);
    onClose () => notif.set(editingDeviceMetadata: false, editingDeviceMetrics: false, editingDeviceDataSources: false); 
    toText(option) => option as String;

    return SelectDialog(
      options: options,
      dialogType: SelectDialogType.checkbox,
      isSelectedFn: isSelectedFn,
      onChanged: onChanged,
      onClose: onClose,
      toText: toText,
    );
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

    Widget _makeDeleteConfirmDialog() {
    final itemSelection = ref.read(itemEditSelectionNotifier);

    bool showConfirmDialog = itemSelection.confirmDeletion;

    if (!showConfirmDialog) { return SizedBox.shrink(); }

    return OptionDialog(
        dialogType: OptionDialogType.cancelDelete,
        title: Text("Confirmar acción"),
        confirmMessage: Text("(Los cambios no serán apliacados todavía)"),
        onCancel: onCancelDelete,
        onDelete: onConfirmedDelete,
      );
  }

  Widget _buildConfigurationPage() {
    return Column(
      children: [ Expanded(child: SettingsList( sections: [
              CustomSettingsSection(child: DeviceGeneralSettings(widget.topology,)),
              CustomSettingsSection(child: DeviceLinkSettings   (widget.topology)),
              CustomSettingsSection(child: DeviceGroupSettings  (widget.topology)),
              CustomSettingsSection(child: DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore))
            ],
          ),
        ) ,
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  Stack buildSettings() {
    return Stack(
      children: [
        _buildConfigurationPage(),
        _buildSelectionDialog(),
        _buildGeoInputDialog(),
        _makeDeleteConfirmDialog(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildSettings();
  }
}