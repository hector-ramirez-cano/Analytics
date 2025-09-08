import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/checkbox_select_dialog.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends ConsumerStatefulWidget {
  final Device device;
  final Topology topology;

  static const Icon nameIcon         = Icon(Icons.label);
  static const Icon mgmtHostnameIcon = Icon(Icons.dns);
  static const Icon geoPositionIcon  = Icon(Icons.map);
  static const Icon metadataIcon     = Icon(Icons.list);
  static const Icon metricsIcon      = Icon(Icons.list_alt);
  static const Icon linksIcon        = Icon(Icons.settings_ethernet);
  static const Icon groupsIcon       = Icon(Icons.folder);

  const DeviceEditView({
    super.key,
    required this.device,
    required this.topology,
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

    onEdit() {} // TODO: Functionality

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
    List<BadgeButton> list = [];
    Color backgroundColor = Colors.white;
    for (var item in widget.device.requestedMetadata) {
      list.add(BadgeButton(backgroundColor: backgroundColor, text: item));
    }

    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    onEdit() => ref.read(itemEditSelectionNotifier.notifier).set(editingDeviceMetadata: true);

    return SettingsTile(
      title: const Text("Metadatos a recabar"),
      description: const Text("Útil para valores que no cambian frecuentemente"),
      leading: DeviceEditView.metadataIcon,
      trailing: makeTrailing(metadata, onEdit, width: 440),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeMetricInput() {
    List<BadgeButton> list = [];
    Color backgroundColor = Colors.white;
    for (var item in widget.device.requestedMetrics) {
      list.add(BadgeButton(backgroundColor: backgroundColor, text: item));
    }

    var metadata = Wrap(spacing: 4, runSpacing: 4, children: list,);

    onEdit() => ref.read(itemEditSelectionNotifier.notifier).set(editingDeviceMetrics: true);

    return SettingsTile(
      title: const Text("Métricas a recabar"),
      description: const Text("Útil para valores que fluctúan frecuentemente"),
      leading: DeviceEditView.metricsIcon,
      trailing: makeTrailing(metadata, onEdit, width: 440),
      onPressed: null
    );
  }

  List<AbstractSettingsTile> _makeLinks(WidgetRef ref) {
    List<AbstractSettingsTile> list = [];
    for (var link in widget.topology.getDeviceLinks(widget.device)) {
      list.add(SettingsTile(
        title: Text(link.sideB.name),
        leading: DeviceEditView.linksIcon,
        onPressed: (_) => ref.read(itemEditSelectionNotifier.notifier).setSelected(link),
      ));
    }

    return list;
  }

  List<AbstractSettingsTile> _makeGroups(WidgetRef ref) {
    List<AbstractSettingsTile> list = [];
    for (var group in widget.topology.getDeviceGroups(widget.device)) {
      list.add(SettingsTile(
        title: Text(group.name),
        leading: DeviceEditView.groupsIcon,
        onPressed: (_) => ref.read(itemEditSelectionNotifier.notifier).setSelected(group),
      ));
    }

    return list;
  }


  Widget _buildValueSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    bool enabled = itemEditSelection.editingDeviceMetrics || itemEditSelection.editingDeviceMetadata;

    if (!enabled) { return SizedBox.shrink(); }

    isSelected (option) => widget.device.availableValues.contains(option);
    onChanged (option, state) => {}; // TODO: Functionality
    title(option) => title;
    var options = widget.device.availableValues;

    return CheckboxSelectDialog(options: options, isSelected: isSelected, onChanged: onChanged, title: title,);
  }

  Widget _buildConfigurationPage() {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(notifier.selected.name),
                tiles: [
                  _makeDeviceInput(),
                  _makeHostnameInput(),
                  _makeGeopositionInput(),
                  _makeMetadataInput(),
                  _makeMetricInput()
                ],
              ),

              SettingsSection(
                title: Text("Links"),
                tiles: _makeLinks(ref),
              ),

              SettingsSection(
                title: Text("Grupos"),
                tiles: _makeGroups(ref)
              )
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
    
    // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected && next.selected is Device) {
          _nameInputController.text = next.selected.name;
          _hostnameInputController.text = next.selected.mgmtHostname;
        }
      });

    return Stack(
      children: [
        _buildConfigurationPage(),
        _buildValueSelectionInput(),
      ],
    );
  }
}