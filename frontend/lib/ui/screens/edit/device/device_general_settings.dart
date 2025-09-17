import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_text_field.dart';
import 'package:settings_ui/settings_ui.dart';


class DeviceGeneralSettings extends ConsumerStatefulWidget {
  const DeviceGeneralSettings(
    this.topology,
    { super.key, }
  );

  final Topology topology;

  static const Icon nameIcon         = Icon(Icons.label);
  static const Icon mgmtHostnameIcon = Icon(Icons.dns);
  static const Icon geoPositionIcon  = Icon(Icons.map);
  static const Icon metadataIcon     = Icon(Icons.list);
  static const Icon metricsIcon      = Icon(Icons.list_alt);
  static const Icon dataSourcesIcon  = Icon(Icons.dataset_linked);

  @override
  ConsumerState<DeviceGeneralSettings> createState() => _DeviceGeneralSettingsState();
}

class _DeviceGeneralSettingsState extends ConsumerState<DeviceGeneralSettings> {
  late TextEditingController _hostnameInputController;
  late TextEditingController _nameInputController;

  void onEditDeviceHostname() => ref.read(itemEditSelectionProvider.notifier).onEditDeviceHostname();
  void onEditDeviceName()     => ref.read(itemEditSelectionProvider.notifier).onEditDeviceName();
  void onEditGeoposition()    => ref.read(itemEditSelectionProvider.notifier).onEditDeviceGeoposition();
  void onEditMetadata()       => ref.read(itemEditSelectionProvider.notifier).onEditMetadata();
  void onEditMetrics()        => ref.read(itemEditSelectionProvider.notifier).onEditMetrics();
  void onEditDataSources()    => ref.read(itemEditSelectionProvider.notifier).onEditDataSources();

  void onEditDeviceMgmtHostnameContent(String text) => ref.read(itemEditSelectionProvider.notifier).onChangeDeviceMgmtHostname(text);
  void onEditDeviceNameContent(String text) => ref.read(itemEditSelectionProvider.notifier).onChangeDeviceNameContent(text);

  AbstractSettingsTile _makeDeviceInput(Device device, bool editing, Topology topology) {
    bool modified = device.isModifiedName(topology);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;

    var editInput = EditTextField(
      initialText: device.name,
      enabled: editing,
      showEditIcon: true,
      backgroundColor: backgroundColor,
      controller: _nameInputController,
      onEditToggle: onEditDeviceName,
      onContentEdit: onEditDeviceNameContent,
    );

    return SettingsTile(
      title: Text("Nombre"),
      leading: DeviceGeneralSettings.nameIcon,
      trailing: editInput,
    );
  }

  AbstractSettingsTile _makeHostnameInput(Device device, bool enabled, Topology topology) {
    bool modified = device.isModifiedHostname(topology);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;

    final editInput = EditTextField(
      initialText: device.name,
      enabled: enabled,
      showEditIcon: true,
      backgroundColor: backgroundColor,
      controller: _hostnameInputController,
      onEditToggle: onEditDeviceHostname,
      onContentEdit: onEditDeviceMgmtHostnameContent,
    );

    return SettingsTile(
      title: Text("Hostname"),
      leading: const Icon(Icons.dns),
      trailing: editInput,
    );
  }

  AbstractSettingsTile _makeGeopositionInput(Device device) {
    bool modified = device.isModifiedGeoLocation(widget.topology);
    TextStyle? style = modified ? TextStyle(backgroundColor: addedItemColor, color: Colors.white) : null;

    double lat = device.geoPosition.latitude;
    double lng = device.geoPosition.longitude;
    var child = Text(
      "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
      style: style,
    );
    
    return SettingsTile(
      title: Text("Geoposition"),
      leading: DeviceGeneralSettings.geoPositionIcon,
      trailing: makeTrailing(child, onEditGeoposition),
    );
  }

  List<BadgeButton> _makeBadgeList(
    Set<String> values,
    Topology topology,
    bool Function(String, Topology) isModifiedFn,
    bool Function(String, Topology) isDeletedFn
  ) {
    List<BadgeButton> list = [];
    for (var item in values) {
      bool modified = isModifiedFn(item, topology);
      bool deleted = isDeletedFn(item, topology);

      Color backgroundColor = modified ? addedItemColor : Color.fromRGBO(214, 214, 214, 1);
      backgroundColor = deleted ? deletedItemColor : backgroundColor;
      
      Color textColor = modified ? Colors.white : Colors.black;

      list.add(
        BadgeButton(
          backgroundColor: backgroundColor,
          text: item,
          textStyle: TextStyle(color: textColor),
        ));
    }

    return list;
  }

  AbstractSettingsTile _makeMetadataInput(Device device, Device merged, Topology topology) {

    List<BadgeButton> list = _makeBadgeList(merged.requestedMetadata, topology, device.isModifiedMetadata, device.isDeletedMetadata);
    
    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    return SettingsTile(
      title: const Text("Metadatos a recabar"),
      description: const Text("Útil para valores que no cambian frecuentemente"),
      leading: DeviceGeneralSettings.metadataIcon,
      trailing: makeTrailing(metadata, onEditMetadata, width: 440),
    );
  }

  AbstractSettingsTile _makeMetricInput(Device device, Device merged, Topology topology) {
    List<BadgeButton> list = _makeBadgeList(merged.requestedMetrics, topology, device.isModifiedMetric, device.isDeletedMetric);
    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    return SettingsTile(
      title: const Text("Métricas a recabar"),
      description: const Text("Útil para valores que fluctúan frecuentemente"),
      leading: DeviceGeneralSettings.metricsIcon,
      trailing: makeTrailing(metadata, onEditMetrics, width: 440),
    );
  }

  AbstractSettingsTile _makeDataSourceInput(Device device, Device merged, Topology topology) {
    List<BadgeButton> list = _makeBadgeList(merged.dataSources, topology, device.isModifiedDataSources, device.isDeletedDataSource);
    var dataSources = Wrap(spacing: 4, runSpacing: 4, children: list,);

    return SettingsTile(
      title: const Text("Fuentes de datos"),
      description: const Text("Fuentes de métricas y metadatos"),
      leading: DeviceGeneralSettings.dataSourcesIcon,
      trailing: makeTrailing(dataSources, onEditDataSources, width: 440),
    );
  }

  @override
  void initState() {
    super.initState();
    
    var device = ref.read(itemEditSelectionProvider.notifier).device;
    _hostnameInputController = TextEditingController(text: device.mgmtHostname);
    _nameInputController = TextEditingController(text: device.name);
  }

  @override
  void dispose() {
    _hostnameInputController.dispose();
    _nameInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    final itemSelectionService = ref.read(itemEditSelectionProvider);

    // If item changed, reset the text field controller's text to the initial value of the selected
    ref.listen(itemEditSelectionProvider, (previous, next) {
        if (next.selectedStack.lastOrNull is Device) {
          Device device = notifier.device;
          _hostnameInputController.text = device.mgmtHostname;
          _nameInputController.text = device.name;
        }
      });

    
    Device device = notifier.device;
    Device merged = notifier.deviceMerged;
    bool enableDeviceName = itemSelectionService.editingDeviceName;
    bool enableHostname = itemSelectionService.editingDeviceHostname;

    return SettingsSection(
        title: Text(notifier.device.name),
        tiles: [
          _makeDeviceInput(device, enableDeviceName, widget.topology),
          _makeHostnameInput(device, enableHostname, widget.topology),
          _makeGeopositionInput(device),
          _makeDataSourceInput(device, merged, widget.topology),
          _makeMetadataInput(device, merged, widget.topology),
          _makeMetricInput(device, merged, widget.topology),
        ],
      );
  }
}
