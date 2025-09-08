import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/topology_tree.dart';



class ItemEditPanel extends StatelessWidget {
  final Topology topology;

  const ItemEditPanel({
    super.key,
    required this.topology,
  });

  void onChangeItem(WidgetRef ref, TreeNode value) {
    if(value.data is Section) {
      return;
    }

    if(value.data is Device) {
      ref.read(itemEditSelectionNotifier.notifier).setSelected(value.data);
    }

    if(value.data is Group) {
      ref.read(itemEditSelectionNotifier.notifier).setSelected(value.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        onItemTap(value) => onChangeItem(ref, value);

        return TopologyTree(
          topology: topology,
          includeDevices: true,
          includeGroups: true,
          onItemTap: onItemTap,
        );
      },
    );
  }
}