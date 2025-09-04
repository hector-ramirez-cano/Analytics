import 'package:flutter/material.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends StatefulWidget {
  final Device device;


  const DeviceEditView({
    super.key,
    required this.device
  });

  @override
  State<DeviceEditView> createState() => _DeviceEditViewState();
}

class _DeviceEditViewState extends State<DeviceEditView> {

  bool editingDeviceName = false;
  bool editingHostname = false;

  AbstractSettingsTile _makeDeviceInput() {
    var child = makeTrailingInput(widget.device.name, editingDeviceName);

    onEdit() {
      setState(() {
        editingDeviceName = !editingDeviceName;
        editingHostname = false;
      });
    }

    return SettingsTile(
      title: Text("Nombre"),
      leading: const Icon(Icons.computer),
      trailing: makeTrailing(child, onEdit),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeGeopositionInput() {
    var child = Text("${widget.device.geoPosition.dx}, ${widget.device.geoPosition.dy}");

    onEdit() {}

    return SettingsTile(
      title: const Text("Geoposition"),
      leading: const Icon(Icons.map),
      trailing: makeTrailing(child, onEdit),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeHostnameInput() {
    var child = makeTrailingInput(widget.device.mgmtHostname, editingHostname);

    onEdit() {
      setState(() {
        editingHostname = !editingHostname;
        editingDeviceName = false;
      });
    }

    return SettingsTile(
      title: Text("Hostname"),
      leading: const Icon(Icons.dns),
      trailing: makeTrailing(child, onEdit),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeMetadataInput() {
    return SettingsTile(
      title: const Text("Requested Metadata"),
      leading: const Icon(Icons.list),
      onPressed: null
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(widget.device.name),
                tiles: [
                  _makeDeviceInput(),
                  _makeHostnameInput(),
                  _makeGeopositionInput(),
                  _makeMetadataInput(),
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