import 'package:flutter/material.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceEditView extends StatelessWidget {
  
  final String deviceName;
  final String managementHostname;
  final Offset geoPosition;

  const DeviceEditView({
    super.key,
    required this.deviceName,
    required this.managementHostname,
    required this.geoPosition,
  });


  AbstractSettingsTile _makeDeviceInput() {
    var child = makeTrailingInput(deviceName);

    return SettingsTile(
      title: Text(deviceName),
      leading: const Icon(Icons.computer),
      trailing: makeTrailing(child),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeGeopositionInput() {
    var child = Text("${geoPosition.dx}, ${geoPosition.dy}");

    return SettingsTile(
      title: const Text("Geoposition"),
      leading: const Icon(Icons.map),
      trailing: makeTrailing(child),
      onPressed: null
    );
  }

  AbstractSettingsTile _makeHostnameInput() {
    var child = makeTrailingInput(managementHostname);
    return SettingsTile(
      title: Text(managementHostname),
      leading: const Icon(Icons.dns),
      trailing: makeTrailing(child),
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
                title: Text(deviceName),
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