import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class DeviceLinkSettings extends StatelessWidget {

  static const Icon linksIcon = Icon(Icons.settings_ethernet);

  final Topology topology;

  const DeviceLinkSettings(this.topology, {super.key});

  List<AbstractSettingsTile> _makeLinks(WidgetRef ref, Device device) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    List<AbstractSettingsTile> list = [];
    for (var link in topology.getDeviceLinks(device)) {
      bool deleted = notifier.isDeleted(link);
      Color backgroundColor = deleted ? deletedItemColor : Colors.transparent;

      list.add(SettingsTile(
        title: Text(link.sideB.name, style: TextStyle(backgroundColor: backgroundColor),),
        leading: linksIcon,
        onPressed: (_) => notifier.setSelected(link),
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
        title: Text("Links"),
        tiles: _makeLinks(ref, device),
      );
    });
  }

}