import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/enums/item_type.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/edit/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/link_edit_view.dart';

class ItemEditView extends StatelessWidget {
  const ItemEditView({
    super.key,
  });


  Widget _makeSettingsView(Topology topology) {
    var type = ItemType.link;
    Device deviceA = Device(id: -1, position: Offset.zero, name: "Xochimilco-lan", geoPosition: Offset.zero);
    Device deviceB = Device(id: -1, position: Offset.zero, name: "Tlatelolco-lan", geoPosition: Offset.zero);
    LinkType linkType = LinkType.copper;

    // TODO: show change resume before applying to DB
    switch (type) {
      case ItemType.device:
        return DeviceEditView(deviceName: "Nombre", managementHostname: "hostname", geoPosition: Offset(-21.54315, 54.455143),);

      case ItemType.link:
        return LinkEditView(deviceA: deviceA, deviceB: deviceB, linkType: linkType, topology: topology);
        
      case ItemType.group:
        // TODO: Handle this case.
        throw UnimplementedError();

      
      // Keep it, in case new type are added
      // ignore: unreachable_switch_default
      default:
        Logger().w("Creating item edit page for item type not defined or missing!");
        return Text("Nobody here but us, chickens!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        final topologyAsync = ref.watch(topologyProvider);

        onRetry () async => {
          ref.refresh(topologyProvider.future)
        };

        return topologyAsync.when(
          loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
          error: (error, st) => RetryIndicator(onRetry: onRetry, isLoading: false, error: error.toString(),),
          data: (topology) => _makeSettingsView(topology),
        );
      },
    );
  }
  
}