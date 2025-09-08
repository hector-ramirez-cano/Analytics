import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/edit/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/empty_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/group_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/link_edit_view.dart';

class ItemEditView extends StatelessWidget {
  const ItemEditView({
    super.key,
  });


  Widget _makeSettingsView(Topology topology, dynamic selected) {
    var type = selected.runtimeType;

    if (selected == null) {
      return EmptyEditView();
    }

    // TODO: show change resume before applying to DB
    switch (type) {
      case const (Device):
        return DeviceEditView(device: selected, topology: topology,);

      case const (Link):
        return LinkEditView(link: selected, topology: topology);
        
      case const (Group):
        return GroupEditView(topology: topology,);
        

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
        final itemEditSelection = ref.watch(itemEditSelectionNotifier);

        onRetry () async => {
          ref.refresh(topologyProvider.future)
        };

        return topologyAsync.when(
          loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
          error: (error, st) => RetryIndicator(onRetry: onRetry, isLoading: false, error: error.toString(),),
          data: (topology) => _makeSettingsView(topology, itemEditSelection.selected),
        );
      },
    );
  }
  
}