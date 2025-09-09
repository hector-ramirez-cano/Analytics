import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
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

  @override
  ConsumerState<DeviceGeneralSettings> createState() => _DeviceGeneralSettingsState();
}

class _DeviceGeneralSettingsState extends ConsumerState<DeviceGeneralSettings> {
  late TextEditingController _hostnameInputController;
  late TextEditingController _nameInputController;

  void onEditDeviceHostname() => ref.read(itemEditSelectionNotifier.notifier).onEditDeviceHostname();
  void onEditDeviceName()     => ref.read(itemEditSelectionNotifier.notifier).onEditDeviceName();
  void onEditGeoposition()    => ref.read(itemEditSelectionNotifier.notifier).onEditDeviceGeoposition();
  void onEditMetadata()       => ref.read(itemEditSelectionNotifier.notifier).onEditMetadata();
  void onEditMetrics()        => ref.read(itemEditSelectionNotifier.notifier).onEditMetrics();

  void onEditDeviceMgmtHostnameContent(String text) => ref.read(itemEditSelectionNotifier.notifier).onChangeDeviceMgmtHostname(text);
  void onEditDeviceNameContent(String text) => ref.read(itemEditSelectionNotifier.notifier).onChangeDeviceNameContent(text);


  AbstractSettingsTile _makeDeviceInput(Device device, bool editing, Topology topology) {
    bool modified = device.isModifiedName(topology);
    Color backgroundColor = modified ? modifiedColor : Colors.transparent;

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
      onPressed: null
    );
  }


  AbstractSettingsTile _makeHostnameInput(Device device, bool enabled, Topology topology) {
    bool modified = device.isModifiedHostname(topology);
    Color backgroundColor = modified ? modifiedColor : Colors.transparent;

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
      onPressed: null
    );
  }


AbstractSettingsTile _makeGeopositionInput(Device device) {
    bool modified = device.isModifiedGeoLocation(widget.topology);
    TextStyle? style = modified ? TextStyle(backgroundColor: modifiedColor, color: Colors.white) : null;

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
      onPressed: null
    );
  }

  
  AbstractSettingsTile _makeMetadataInput(Device device, Topology topology) {
    List<BadgeButton> list = [];
    for (var item in device.requestedMetadata) {
      bool modified = device.isModifiedMetadata(item, topology);

      Color backgroundColor = modified ? modifiedColor : Color.fromRGBO(214, 214, 214, 1);
      Color textColor = modified ? Colors.white : Colors.black;

      list.add(
        BadgeButton(
          backgroundColor: backgroundColor,
          text: item,
          textStyle: TextStyle(color: textColor),
        ));
    }

    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    

    return SettingsTile(
      title: const Text("Metadatos a recabar"),
      description: const Text("Útil para valores que no cambian frecuentemente"),
      leading: DeviceGeneralSettings.metadataIcon,
      trailing: makeTrailing(metadata, onEditMetadata, width: 440),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeMetricInput(Device device, Topology topology) {
    List<BadgeButton> list = [];
    for (var item in device.requestedMetrics) {
      bool modified = device.isModifiedMetric(item, topology);

      Color backgroundColor = modified ? modifiedColor : Color.fromRGBO(214, 214, 214, 1);
      Color textColor = modified ? Colors.white : Colors.black;

      list.add(
        BadgeButton(
          backgroundColor: backgroundColor,
          textStyle: TextStyle(color: textColor),
          text: item
        ));
    }

    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    return SettingsTile(
      title: const Text("Métricas a recabar"),
      description: const Text("Útil para valores que fluctúan frecuentemente"),
      leading: DeviceGeneralSettings.metricsIcon,
      trailing: makeTrailing(metadata, onEditMetrics, width: 440),
      onPressed: null
    );
  }

  @override
  void initState() {
    super.initState();
    
    var selected = ref.read(itemEditSelectionNotifier).selected;
    _hostnameInputController = TextEditingController(text: selected.mgmtHostname);
    _nameInputController = TextEditingController(text: selected.name);
  }


  @override
  void dispose() {
    _hostnameInputController.dispose();
    _nameInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemSelectionService = ref.read(itemEditSelectionNotifier);

    // If item changed, reset the text fiel controller's text to the initial value of the selected
    ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected && next.selected is Device) {
          Device device = notifier.device;
          _hostnameInputController.text = device.mgmtHostname;
          _nameInputController.text = device.name;
        }
      });

    
    Device device = notifier.device;
    bool enableDeviceName = itemSelectionService.editingDeviceName;
    bool enableHostname = itemSelectionService.editingDeviceHostname;

    return SettingsSection(
        title: Text(notifier.device.name),
        tiles: [
          _makeDeviceInput(device, enableDeviceName, widget.topology),
          _makeHostnameInput(device, enableHostname, widget.topology),
          _makeGeopositionInput(device),
          _makeMetadataInput(device, widget.topology),
          _makeMetricInput(device, widget.topology)
        ],
      );
  }
}
