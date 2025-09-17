import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
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
    final notifier = ref.read(itemEditSelectionProvider.notifier);

    for (var group in topology.getDeviceGroups(device)) {
      bool deleted = notifier.isDeleted(group);
      Color backgroundColor = deleted ? deletedItemColor : Colors.transparent;

      list.add(SettingsTile(
        title: Text(group.name, style: TextStyle(backgroundColor: backgroundColor)),
        leading: groupsIcon,
        onPressed: (_) => ref.read(itemEditSelectionProvider.notifier).setSelected(group, appendState: true),
      ));
    }

    return list;
  }


  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final notifier = ref.read(itemEditSelectionProvider.notifier);
      Device device = notifier.device;

      return SettingsSection(
        title: Text("Grupos"),
        tiles: _makeGroups(ref, device)
      );
    });
  }
}