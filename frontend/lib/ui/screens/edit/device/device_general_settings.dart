import 'package:aegis/extensions/string_extensions.dart';
import 'package:aegis/services/metrics/metadata_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:aegis/models/data_sources.dart';
import 'package:aegis/models/device.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/dialog_change_notifier.dart';
import 'package:aegis/services/item_edit_selection_notifier.dart';
import 'package:aegis/ui/components/badge_button.dart';
import 'package:aegis/ui/components/dialogs/geo_selection_dialog.dart';
import 'package:aegis/ui/components/dialogs/tag_selection_dialog.dart';
import 'package:aegis/ui/components/list_selector.dart';
import 'package:aegis/ui/screens/edit/commons/edit_commons.dart';
import 'package:aegis/ui/screens/edit/commons/edit_text_field.dart';
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
  static const Icon dataSourcesIcon  = Icon(Icons.dataset);

  @override
  ConsumerState<DeviceGeneralSettings> createState() => _DeviceGeneralSettingsState();
}

class _DeviceGeneralSettingsState extends ConsumerState<DeviceGeneralSettings> {
  late TextEditingController _hostnameInputController;
  late TextEditingController _nameInputController;

  // callbacks that modify the state
  void onEditDeviceHostname() => ref.read(itemEditSelectionProvider.notifier).onEditDeviceHostname();
  void onEditDeviceName()     => ref.read(itemEditSelectionProvider.notifier).onEditDeviceName();

  // callbacks that show a dialog and modify the state
  void onEditGeoposition()    { ref.read(itemEditSelectionProvider.notifier).onEditDeviceGeoposition(); _displayGeoInputDialog();  }
  void onEditMetadata()       { ref.read(itemEditSelectionProvider.notifier).onEditMetadata();          _displaySelectionDialog(); }
  void onEditMetrics()        { ref.read(itemEditSelectionProvider.notifier).onEditMetrics();           _displaySelectionDialog(); }
  void onEditDataSources()    { ref.read(itemEditSelectionProvider.notifier).onEditDataSources();       _displaySelectionDialog(); }

  // callbacks that modify the data
  void onGeoPositionChanged(LatLng p) => ref.read(itemEditSelectionProvider.notifier).onChangeDeviceGeoPosition(p);
  void onEditDeviceMgmtHostnameContent(String text) => ref.read(itemEditSelectionProvider.notifier).onChangeDeviceMgmtHostname(text);
  void onEditDeviceNameContent(String text) => ref.read(itemEditSelectionProvider.notifier).onChangeDeviceNameContent(text);

  AbstractSettingsTile _makeDeviceInput(Device device, bool editing, Topology topology) {
    bool modified = device.isModifiedName(topology);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;

    _nameInputController.selection = TextSelection.collapsed(offset: _nameInputController.selection.extentOffset);

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
      description: const Text("Útil para valores que no cambian frecuentemente. Se almacenan en Caché"),
      leading: DeviceGeneralSettings.metadataIcon,
      trailing: makeTrailing(metadata, onEditMetadata, width: 440),
    );
  }

  AbstractSettingsTile _makeMetricInput(Device device, Device merged, Topology topology) {
    List<BadgeButton> list = _makeBadgeList(merged.requestedMetrics, topology, device.isModifiedMetric, device.isDeletedMetric);
    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    return SettingsTile(
      title: const Text("Métricas a recabar"),
      description: const Text("Útil para valores que fluctúan frecuentemente. Se almacenan en InfluxDB"),
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

  void _displaySelectionDialog() {
    final ItemEditSelection itemEditSelection = ref.watch(itemEditSelectionProvider);
    final notif = ref.watch(itemEditSelectionProvider.notifier);
    bool metrics = itemEditSelection.editingDeviceMetrics;
    bool metadata = itemEditSelection.editingDeviceMetadata;
    bool datasources = itemEditSelection.editingDeviceDataSources;

    bool enabled = metrics || metadata || datasources;

    if (!enabled) { return; }

    Set<String> options;
    if      (metrics)     { options = {...notif.device.availableValues, ...notif.device.requestedMetrics}; }
    else if (metadata)    { options = {...notif.device.availableValues, ...notif.device.requestedMetadata}; }
    else if (datasources) { options = DataSources.values.map((i) => i.name).toSet(); }
    else { return; }


    bool isSelectedFn(option) {
      if      (metrics)     { return notif.device.requestedMetrics.contains(option);}
      else if (metadata)    { return notif.device.requestedMetadata.contains(option);}
      else if (datasources) { return notif.device.dataSources.contains(option);}
      else { return false; }
    }

    bool isAvailableFn(option) {
      if      (metrics)     { return notif.device.availableValues.contains(option); }
      else if (metadata)    { return notif.device.availableValues.contains(option); }
      else if (datasources) { return DataSources.values.map((i) => i.name).toSet().contains(option);}
      else { return false; }
    }

    onChanged (option, state) {
      if      (metrics)  { notif.onChangeSelectedMetric(option, state); }
      else if (metadata) { notif.onChangeSelectedMetadata(option, state); }
      else if (datasources) {notif.onChangeSelectedDatasource(option, state); }
      else {
        throw Exception("Unreachable code reached! Logic is faulty!");
      }
      ref.watch(dialogRebuildProvider.notifier).markDirty();
    }
    onClose () => notif.set(editingDeviceMetadata: false, editingDeviceMetrics: false, editingDeviceDataSources: false);

    Widget onDisplayTrailing(dynamic option) {
      return Consumer(
        key: Key("device_settings_dialog_${option.toString()}_${notif.selected.id}"),
        builder:(context, ref, child) {
        final metadata = ref.watch(metadataServiceProvider(metadata: option.toString(), deviceId: notif.selected.id));
        return metadata.when(
          data: (metadata) => Text(metadata.toString().truncate(50)),
          error: (_, _) => Text("Sin datos"),
          loading: () => Text("Cargando...")
        );
      },);
    } 

    TagSelectionDialog(
      options: options,
      selectorType: ListSelectorType.checkbox,
      onChanged: onChanged,
      onClose: onClose,
      isSelectedFn: isSelectedFn,
      isAvailable: isAvailableFn,
      onDisplayTrailing: onDisplayTrailing
    ).show(context);
  }

  void _displayGeoInputDialog() {
    final itemEditSelection = ref.read(itemEditSelectionProvider);
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    bool enabled = itemEditSelection.editingDeviceGeoPosition;
    LatLng initialPosition = notifier.device.geoPosition;

    if (!enabled) { return; }

    onClose() => ref.read(itemEditSelectionProvider.notifier).set(editingDeviceGeoPosition: false);

    GeoSelectionDialog(
      initialPosition: initialPosition,
      onClose: onClose,
      onGeoPositionChanged: onGeoPositionChanged
    ).show(context);
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
        if (next.selectedStack.lastOrNull is Device && previous?.selectedStack.lastOrNull is Device) {
          Device device = notifier.device;
          Device prev = previous!.selectedStack.lastOrNull as Device;

          if (prev.id != device.id) {
            _hostnameInputController.text = device.mgmtHostname;
            _nameInputController.text = device.name;
          }
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
