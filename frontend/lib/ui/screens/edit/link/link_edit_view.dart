import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  AbstractSettingsTile _makeInterfaceInput(
    Link link,
    bool enabled,
    String startingText,
    TextEditingController inputController,
    Topology topology,
    bool Function(Topology) isModified,
    Function() onEdit,
    Function(String) onContentEdit
  ) {
    bool modified = isModified(topology);
    Color backgroundColor = modified ? modifiedColor : Colors.transparent;

    var editInput = EditTextField(
      initialText: startingText,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: inputController,
      showEditIcon: true,
      onEditToggle: onEdit,
      onContentEdit: onContentEdit,
    );

    return SettingsTile(
      title: Text("Interface"),
      leading: const Icon(Icons.settings_ethernet),
      trailing: editInput,
    );
  }

  AbstractSettingsTile _makeInterfaceAInput(Link link, bool enabled, Topology topology) {
    return _makeInterfaceInput(link, enabled, link.sideAIface, _sideAIfaceInputController, topology, link.isModifiedAIface, onEditSideAIface, onEditSideAIfaceContent);
  }

  AbstractSettingsTile _makeInterfaceBInput(Link link, bool enabled, Topology topology) {
    return _makeInterfaceInput(link, enabled, link.sideBIface, _sideBIfaceInputController, topology, link.isModifiedBIface, onEditSideBIface, onEditSideBIfaceContent);
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

  SettingsSection _makeLinkSelection(Link link) {
    var child = _makeLinkTypeDropdown(link.linkType);

    return SettingsSection(
        title: Text("Link type"),
        tiles: [
          SettingsTile(
            title: const Text("Link Type"),
            leading: const Icon(Icons.cable),
            trailing: makeTrailing(child, (){}, showEditIcon: false),
          )
        ],
      );
  }

  SettingsSection _makeDeviceSection(String title, Device device, Device other, Link link, bool editing, Function(Link, bool, Topology) makeInput) {
    return SettingsSection(
        title: Text(title),
        tiles: [
          _makeDeviceSelection("Device", link.sideA, link.sideB),
          makeInput(link, editing , widget.topology),
        ],
      );
  }

  Widget _buildConfigurationPage() {
    final itemSelection = ref.read(itemEditSelectionNotifier);
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    Link link = notifier.link;
    bool editingAIface = itemSelection.editingLinkIfaceA;
    bool editingBIface = itemSelection.editingLinkIfaceB;

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              CustomSettingsSection(child: _makeDeviceSection("Device A", link.sideA, link.sideB, link, editingAIface, _makeInterfaceAInput)),
              CustomSettingsSection(child: _makeDeviceSection("Device B", link.sideB, link.sideA, link, editingBIface, _makeInterfaceBInput)),
              CustomSettingsSection(child: _makeLinkSelection(link))
            ],),),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
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

    return Stack(
      children: [
        _buildConfigurationPage(),

      ],
    );
  }
}