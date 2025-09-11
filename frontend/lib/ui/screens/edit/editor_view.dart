import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/edit/device/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/empty_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/group/group_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/link/link_edit_view.dart';

class ItemEditView extends StatelessWidget {
  const ItemEditView({
    super.key,
  });

  Widget _makeAnimatedSettings(Topology topology, WidgetRef ref) {
    var item = ref.watch(itemEditSelectionNotifier);
    var selected = item.selectedStack.lastOrNull;
    return AnimatedSwitcher(duration: const Duration (milliseconds: 300), child: _makeSettingsView(topology, selected),);
  }

  // TODO: Possibly remove selected
  Widget _makeSettingsView(Topology topology, dynamic selected) {
    var type = selected.runtimeType;

    if (selected == null) {
      return EmptyEditView();
    }

    // TODO: show change resume before applying to DB
    switch (type) {
      case const (Device):
        return DeviceEditView(topology: topology);

      case const (Link):
        return LinkEditView(topology: topology);
        
      case const (Group):
        return GroupEditView(topology: topology);

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
          data: (topology) => _makeAnimatedSettings(topology, ref),
        );
      },
    );
  }
  
}