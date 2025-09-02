import 'package:flutter/material.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends StatefulWidget {
  
  final String deviceName;
  final String managementHostname;
  final Offset geoPosition;


  const DeviceEditView({
    super.key,
    required this.deviceName,
    required this.managementHostname,
    required this.geoPosition,
  });

  @override
  State<DeviceEditView> createState() => _DeviceEditViewState();
}

class _DeviceEditViewState extends State<DeviceEditView> {

  bool editingDeviceName = false;
  bool editingHostname = false;

  AbstractSettingsTile _makeDeviceInput() {
    var child = makeTrailingInput(widget.deviceName, editingDeviceName);

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
    var child = Text("${widget.geoPosition.dx}, ${widget.geoPosition.dy}");

    onEdit() {}

    return SettingsTile(
      title: const Text("Geoposition"),
      leading: const Icon(Icons.map),
      trailing: makeTrailing(child, onEdit),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeHostnameInput() {
    var child = makeTrailingInput(widget.managementHostname, editingHostname);

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
                title: Text(widget.deviceName),
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