import 'package:flutter/material.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class LinkEditView extends StatelessWidget {
  final Device deviceA;
  final Device deviceB;
  final LinkType linkType;
  final Topology topology;

  final String deviceAIface = "eth0";
  final String deviceBIface = "eth1";

  // TODO: Device Interface
  const LinkEditView({
    super.key,
    required this.deviceA,
    required this.deviceB,
    required this.linkType,
    required this.topology, 
  });

  DropdownButton _makeDeviceDropdown(Device device, String hint) {
    return DropdownButton<String>(
      value: (topology.getDevices().any((d) => d.name == device.name))
          ? device.name
          : null,
      hint: Text(hint),
      items: topology.getDevices()
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


  AbstractSettingsTile _makeInterfaceInput(String title, String ifaceName) {
    var child = makeTrailingInput(ifaceName);

    // TODO: Change icon to FontAwesome ethernet icon
    return SettingsTile(
      title: Text(title),
      leading: const Icon(Icons.settings_ethernet),
      trailing: makeTrailing(child),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeDeviceSelection(String title, Device device) {
    var child = _makeDeviceDropdown(device, "Select device $title");

    return SettingsTile(
      title: Text(title),
      leading: const Icon(Icons.dns),
      trailing: makeTrailing(child, showEditIcon: false),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeLinkSelection() {
    var child = _makeLinkTypeDropdown(linkType);

    return SettingsTile(
      title: const Text("Link Type"),
      leading: const Icon(Icons.cable),
      trailing: makeTrailing(child, showEditIcon: false),
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
                  _makeDeviceSelection("Device", deviceA),
                  _makeInterfaceInput("Interface", deviceAIface),
                ],
              ),
              SettingsSection(
                title: Text("Device B"),
                tiles: [
                  _makeDeviceSelection("Device", deviceB),
                  _makeInterfaceInput("Interface", deviceBIface),
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