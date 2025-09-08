import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends ConsumerStatefulWidget {
  final Device device;

  static const Icon nameIcon         = Icon(Icons.label);
  static const Icon mgmtHostnameIcon = Icon(Icons.dns);
  static const Icon geoPositionIcon  = Icon(Icons.map);
  static const Icon metadataIcon     = Icon(Icons.list);

  const DeviceEditView({
    super.key,
    required this.device
  });

  @override
  ConsumerState<DeviceEditView> createState() => _DeviceEditViewState();
}

class _DeviceEditViewState extends ConsumerState<DeviceEditView> {

  late TextEditingController _nameInputController;
  late TextEditingController _hostnameInputController;

  @override
  void initState() {
    super.initState();
    
    var selected = ref.read(itemEditSelectionNotifier).selected;
    _nameInputController = TextEditingController(text: selected.name);
    _hostnameInputController = TextEditingController(text: selected.mgmtHostname);
  }


  void onEditDeviceName() => ref.read(itemEditSelectionNotifier.notifier).set(editingDeviceName: true);
  void onEditDeviceHostname() => ref.read(itemEditSelectionNotifier.notifier).set(editingHostname: true);

  void onEditDeviceNameContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected is! Device)   { return; }
    if (itemEditSelection.selected.name == text) { return; }

    var device = itemEditSelection.selected;
    var modified = device.cloneWith(name: text);
    notifier.changeItem(modified);
  }

  void onEditDeviceMgmtHostnameContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected is! Device)   { return; }
    if (itemEditSelection.selected.name == text) { return; }

    var device = itemEditSelection.selected;
    var modified = device.cloneWith(mgmtHostname: text);
    notifier.changeItem(modified);
  }

  AbstractSettingsTile _makeDeviceInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    var editInput = EditTextField(
      initialText: notifier.selected.name,
      enabled: itemEditSelection.editingDeviceName,
      showEditIcon: true,
      controller: _nameInputController,
      onEditToggle: onEditDeviceName,
      onContentEdit: onEditDeviceNameContent,
    );

    return SettingsTile(
      title: Text("Nombre"),
      leading: DeviceEditView.nameIcon,
      trailing: editInput,
      onPressed: null
    );
  }

  AbstractSettingsTile _makeGeopositionInput() {
    var child = Text("${widget.device.geoPosition.dx}, ${widget.device.geoPosition.dy}");

    onEdit() {}

    return SettingsTile(
      title: const Text("Geoposition"),
      leading: DeviceEditView.geoPositionIcon,
      trailing: makeTrailing(child, onEdit),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeHostnameInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    final editInput = EditTextField(
      initialText: notifier.selected.name,
      enabled: itemEditSelection.editingDeviceHostname,
      showEditIcon: true,
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

  AbstractSettingsTile _makeMetadataInput() {
    return SettingsTile(
      title: const Text("Requested Metadata"),
      leading: DeviceEditView.metadataIcon,
      onPressed: null
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected) {
          _nameInputController.text = next.selected.name;
          _hostnameInputController.text = next.selected.mgmtHostname;
        }
      });

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(notifier.selected.name),
                tiles: [
                  _makeDeviceInput(),
                  _makeHostnameInput(),
                  _makeGeopositionInput(),
                  _makeMetadataInput(),
                ],
              ),
            ],
          ),
        ) ,
        // Save button and cancel button
        makeFooter(ref),
      ],
    );
  }
}