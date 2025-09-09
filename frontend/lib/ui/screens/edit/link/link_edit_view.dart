import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class LinkEditView extends ConsumerStatefulWidget {
  final Topology topology;


  const LinkEditView({
    super.key,
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
    _sideAIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier.notifier).link.sideAIface);
    _sideBIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier.notifier).link.sideBIface);
  }

  void onEditSideAIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceA: true);
  void onEditSideBIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceB: true);

  void onEditSideAIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    if (notifier.link.sideAIface == text) { return; }

    var link = notifier.link;
    var modified = link.cloneWith(sideAIface: text);
    notifier.changeItem(modified);
  }

  void onEditSideBIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
  
    if (notifier.link.sideBIface == text) { return; }

    var link = notifier.link;
    var modified = link.cloneWith(sideBIface: text);
    notifier.changeItem(modified);
  }


  DropdownButton _makeDeviceDropdown(Device device, Device other, String hint) {
    // TODO: dropdown with search
    final initialValue = (widget.topology.getDevices().any((d) => d.name == device.name))
          ? device.name
          : null;

    final options = widget.topology.getDevices()
          .where((dev) => dev.id != other.id)
          .map((dev) => DropdownMenuItem(value: dev.name, child: Text(dev.name)))
          .toList();

    return DropdownButton<String>(
      value: initialValue,
      hint: Text(hint),
      items: options,
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

  AbstractSettingsTile _makeInterfaceAInput(Link link, bool enabled, Topology topology) {
    
    bool modified = link.isModifiedAIface(topology);
    Color backgroundColor = modified ? modifiedColor : Colors.transparent;


    var editInput = EditTextField(
      initialText: link.sideAIface,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: _sideAIfaceInputController,
      showEditIcon: true,
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

  AbstractSettingsTile _makeInterfaceBInput(Link link, bool enabled, Topology topology) {
    bool modified = link.isModifiedBIface(topology);
    Color backgroundColor = modified ? modifiedColor : Colors.transparent;

    var editInput = EditTextField(
      initialText: link.sideBIface,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: _sideBIfaceInputController,
      showEditIcon: true,
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

  AbstractSettingsTile _makeDeviceSelection(String title, Device device, Device other) {
    var child = _makeDeviceDropdown(device, other, "Select device $title");

    return SettingsTile(
      title: Text(title),
      leading: const Icon(Icons.dns),
      trailing: makeTrailing(child, (){}, showEditIcon: false),
      onPressed: null
    ); 
  }

  AbstractSettingsTile _makeLinkSelection(Link link) {
    var child = _makeLinkTypeDropdown(link.linkType);

    return SettingsTile(
      title: const Text("Link Type"),
      leading: const Icon(Icons.cable),
      trailing: makeTrailing(child, (){}, showEditIcon: false),
      onPressed: null
    );
  }

  @override
  Widget build(BuildContext context) {

    // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected && next.selected is Link) {
          _sideAIfaceInputController.text = next.selected.sideAIface;
          _sideBIfaceInputController.text = next.selected.sideBIface;
        }
      });

    final itemSelection = ref.read(itemEditSelectionNotifier);
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    Link link = notifier.link;
    bool editingAIface = itemSelection.editingLinkIfaceA;
    bool editingBIface = itemSelection.editingLinkIfaceA;

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text("Device A"),
                tiles: [
                  _makeDeviceSelection("Device", link.sideA, link.sideB),
                  _makeInterfaceAInput(link, editingAIface , widget.topology),
                ],
              ),
              SettingsSection(
                title: Text("Device B"),
                tiles: [
                  _makeDeviceSelection("Device", link.sideB, link.sideA),
                  _makeInterfaceBInput(link, editingBIface , widget.topology),
                ],
              ),
              SettingsSection(
                title: Text("Link type"),
                tiles: [
                  _makeLinkSelection(link)
                ],
              ),
            ],
          ),
        ),

        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }
}