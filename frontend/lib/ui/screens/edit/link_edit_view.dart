import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class LinkEditView extends ConsumerStatefulWidget {
  final Link link;
  final Topology topology;


  const LinkEditView({
    super.key,
    required this.link,
    required this.topology, 
  });

  @override
  ConsumerState<LinkEditView> createState() => _LinkEditViewState();
}

class _LinkEditViewState extends ConsumerState<LinkEditView> {

  late TextEditingController _sideAIfaceInputController;
  late TextEditingController _sideBIfaceInputController;

  @override
  void initState() {
    super.initState();
    _sideAIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier).selected.sideAIface);
    _sideBIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier).selected.sideBIface);
  }

  void onEditSideAIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceA: true);
  void onEditSideBIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceB: true);

  void onEditSideAIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected is! Link)     { return; }
    if (itemEditSelection.selected.name == text) { return; }

    var link = itemEditSelection.selected;
    var modified = link.cloneWith(sideAIface: text);
    notifier.changeItem(modified);
  }

  void onEditSideBIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected is! Link)     { return; }
    if (itemEditSelection.selected.name == text) { return; }

    var link = itemEditSelection.selected;
    var modified = link.cloneWith(sideBIface: text);
    notifier.changeItem(modified);
  }


  DropdownButton _makeDeviceDropdown(Device device, String hint) {
    // TODO: dropdown with search
    return DropdownButton<String>(
      value: (widget.topology.getDevices().any((d) => d.name == device.name))
          ? device.name
          : null,
      hint: Text(hint),
      items: widget.topology.getDevices()
          .map((dev) =>
              DropdownMenuItem(value: dev.name, child: Text(dev.name)))
          .toList(),
      onChanged: (val) {}, // TODO: Functionality
      isExpanded: true,
    );
  }

  DropdownButton _makeLinkTypeDropdown(LinkType linkType) {
    return DropdownButton<String>(
    value: linkType.name,
      hint: const Text("Link type"),
      items: LinkType.values
          .map((type) =>
              DropdownMenuItem(value: type.name, child: Text(type.name)))
          .toList(),
      onChanged: (val) {}, // TODO: Functionality
      isExpanded: true,
    );
  }


  AbstractSettingsTile _makeInterfaceAInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    var editInput = EditTextField(
      initialText: notifier.selected.sideAIface,
      enabled: itemEditSelection.editingLinkIfaceA,
      controller: _sideAIfaceInputController,
      onEditToggle: onEditSideAIface,
      onContentEdit: onEditSideAIfaceContent,
    );

    return SettingsTile(
      title: Text("Interface"),
      leading: const Icon(Icons.settings_ethernet),
      trailing: editInput,
      onPressed: null
    );
  }

  AbstractSettingsTile _makeInterfaceBInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    var editInput = EditTextField(
      initialText: notifier.selected.sideBIface,
      enabled: itemEditSelection.editingLinkIfaceB,
      controller: _sideBIfaceInputController,
      onEditToggle: onEditSideBIface,
      onContentEdit: onEditSideBIfaceContent,
    );

    return SettingsTile(
      title: Text("Interface"),
      leading: const Icon(Icons.settings_ethernet),
      trailing: editInput,
      onPressed: null
    );
  }

  AbstractSettingsTile _makeDeviceSelection(String title, Device device) {
    var child = _makeDeviceDropdown(device, "Select device $title");

    return SettingsTile(
      title: Text(title),
      leading: const Icon(Icons.dns),
      trailing: makeTrailing(child, (){}, showEditIcon: false),
      onPressed: null
    );

    
  }

  AbstractSettingsTile _makeLinkSelection() {
    var child = _makeLinkTypeDropdown(widget.link.linkType);

    return SettingsTile(
      title: const Text("Link Type"),
      leading: const Icon(Icons.cable),
      trailing: makeTrailing(child, (){}, showEditIcon: false),
      onPressed: null
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text("Device A"),
                tiles: [
                  _makeDeviceSelection("Device", widget.link.sideA),
                  _makeInterfaceAInput(),
                ],
              ),
              SettingsSection(
                title: Text("Device B"),
                tiles: [
                  _makeDeviceSelection("Device", widget.link.sideB),
                  _makeInterfaceBInput(),
                ],
              ),
              SettingsSection(
                title: Text("Link type"),
                tiles: [
                  _makeLinkSelection()
                ],
              ),
            ],
          ),
        ),

        // Save button and cancel button
        makeFooter(),
      ],
    );
  }
}