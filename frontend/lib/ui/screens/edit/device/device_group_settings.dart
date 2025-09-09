import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceGroupSettings extends StatelessWidget{
  const DeviceGroupSettings(
    this.topology,
    {super.key}
  );

  final Topology topology;

  static const Icon groupsIcon = Icon(Icons.folder);

  List<AbstractSettingsTile> _makeGroups(WidgetRef ref, Device device) {
    List<AbstractSettingsTile> list = [];
    for (var group in topology.getDeviceGroups(device)) {
      list.add(SettingsTile(
        title: Text(group.name),
        leading: groupsIcon,
        onPressed: (_) => ref.read(itemEditSelectionNotifier.notifier).setSelected(group),
      ));
    }

    return list;
  }


  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final notifier = ref.read(itemEditSelectionNotifier.notifier);
      Device device = notifier.device;

      return SettingsSection(
        title: Text("Grupos"),
        tiles: _makeGroups(ref, device)
      );
    });
  }
}