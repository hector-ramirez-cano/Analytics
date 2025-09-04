import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:animated_tree_view/tree_view/tree_view.dart';
import 'package:animated_tree_view/tree_view/widgets/expansion_indicator.dart';
import 'package:animated_tree_view/tree_view/widgets/indent.dart';
import 'package:flutter/material.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';

class Section {
  final String name;
  final IconData icon;

  const Section({
    required this.name,
    required this.icon
  });

}


extension on TreeNode {
  Icon get icon {
    const double iconSize = 16;
    if (isRoot) return const Icon(Icons.account_tree);

    if (this is TreeNode<Section>) {
      return Icon((this as TreeNode<Section>).data!.icon, size: iconSize,);
    }

    if (this is TreeNode<Group>) {
      if (isExpanded) return const Icon(Icons.folder_open, size: iconSize);
      return const Icon(Icons.folder, size: iconSize);
    }

    if (this is TreeNode<Device>) {
      return const Icon(Icons.dns, size: iconSize,);
    }

    return const Icon(Icons.insert_drive_file, size: iconSize);
  }
}

class TopologyTree extends StatelessWidget {
  final Topology topology;
  final bool includeDevices;
  final bool includeGroups;
  final Function(TreeNode) onItemTap;

  const TopologyTree({
    super.key,
    required this.topology,
    required this.includeDevices,
    required this.includeGroups,
    required this.onItemTap
  });

  
  TreeNode _makeDeviceTreeBranch(Group group) {
    var node = TreeNode<Group>(key: UniqueKey().toString(), data: group);


    for (Group subgroup in group.groups) {
      // if it doesn't contain devices, no point on showing it here
      if (!group.hasDevices()) {
        continue;
      }

      node.add(_makeDeviceTreeBranch(subgroup));
    }

    for (Device item in group.devices) {
      node.add(TreeNode<Device>(key: UniqueKey().toString(), data: item));
    }

    return node;
  }

  TreeNode _makeGroupTreeBranch(Group group) {
    var node = TreeNode<Group>(key: UniqueKey().toString(), data: group);

    final groupOrder = List.generate(group.groups.length, (i) => i)
      ..sort((a, b) =>
          group.groups[b].childrenCount().compareTo(group.groups[a].childrenCount()));


    for (final int index in groupOrder) {
      var subgroup = group.groups[index];

      node.add(_makeGroupTreeBranch(subgroup));
    }

    return node;
  }

  TreeNode _makeTree() {
    var root = TreeNode.root();

    var devices = TreeNode<Section>(key: UniqueKey().toString(), data: Section(name: "Dispositivos", icon: Icons.dns));
    var groups  = TreeNode<Section>(key: UniqueKey().toString(), data: Section(name: "Grupos", icon: Icons.folder));

    for (Group group in topology.groups) {
      devices.add(_makeDeviceTreeBranch(group));
    }

    final groupOrder = List.generate(topology.groups.length, (i) => i)
      ..sort((a, b) => topology.groups[b].childrenCount().compareTo(topology.groups[a].childrenCount()));
    for (final int index in groupOrder) {
      var subgroup = topology.groups[index];

      groups.add(_makeGroupTreeBranch(subgroup));
    }

    root.addAll([devices, groups]);
    return root;
  }

  Widget _makeTile(TreeNode node) {
    String title = node.key;
    if (node is TreeNode<Device>) {
      title = node.data?.name ?? "";
    } 
    else if (node is TreeNode<Group>) {
      title = node.data?.name ?? "";
    }
    else if (node is TreeNode<Section>) {
      title = node.data?.name ?? "";
    }

    var iconPadding = node.isLeaf ? EdgeInsets.only(left: 0) : EdgeInsets.only(left: 8);

    return ListTile(
          title: Text(title),
          visualDensity: VisualDensity(horizontal: -4, vertical: -4),
          leading: Padding(padding: iconPadding, child: node.icon,)
      );
  }

  Widget _makeTreeView() {
    return TreeView.simple(
      tree: _makeTree(),
      showRootNode: false,
      indentation: const Indentation(style: IndentStyle.roundJoint),
      expansionIndicatorBuilder: (context, node) {
        return PlusMinusIndicator(
          tree: node,
          alignment: Alignment.centerLeft,
          color: Colors.blueGrey,
        );
      },
      padding: EdgeInsets.all(0),
      expansionBehavior: ExpansionBehavior.snapToTop,
      builder: (context, node) => _makeTile(node),

      onItemTap: onItemTap,
    );
  }


  @override
  Widget build(BuildContext context) {
    return _makeTreeView();
  }
}