import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/components/topology_tree.dart';


// Rename to drawer for clarity
class ItemEditDrawer extends StatelessWidget {
  final Topology topology;

  const ItemEditDrawer({
    super.key,
    required this.topology,
  });

  void onChangeItem(WidgetRef ref, TreeNode value) {
    if (ref.read(itemEditSelectionProvider).creatingItem) {
      return;
    }

    if(value.data is Section) {
      return;
    }

    if(value.data is Device) {
      ref.read(itemEditSelectionProvider.notifier).setSelected(value.data, clearStack: true);
    }

    if(value.data is Group) {
      ref.read(itemEditSelectionProvider.notifier).setSelected(value.data, clearStack: true);
    }
  }

  void onCreateItem(WidgetRef ref) {
    ref.read(itemEditSelectionProvider.notifier).set(overrideCreatingItem: true, selected: []);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        onItemTap(value) => onChangeItem(ref, value);

        return Column(
          children: [
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => onCreateItem(ref), child: Text("Nuevo"))),
            Padding(padding: EdgeInsetsGeometry.only(top: 4, bottom: 4)),
            Divider(height: 1,),
            Expanded(
              child: TopologyTree(
                topology: topology,
                includeDevices: true,
                includeGroups: true,
                onItemTap: onItemTap,
              ),
            ),
          ],
        );
      },
    );
  }
}