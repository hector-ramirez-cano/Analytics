import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:animated_tree_view/tree_view/tree_view.dart';
import 'package:animated_tree_view/tree_view/widgets/expansion_indicator.dart';
import 'package:animated_tree_view/tree_view/widgets/indent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';

class Section {
  final String name;
  final IconData icon;

  const Section({
    required this.name,
    required this.icon
  });

}

extension on TreeNode {
  Widget get icon {
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
  final bool showRoot;
  final Function(TreeNode) onItemTap;

  const TopologyTree({
    super.key,
    required this.topology,
    required this.includeDevices,
    required this.includeGroups,
    required this.onItemTap,

    this.showRoot = false,
  });

  
  TreeNode _makeDeviceTreeBranch(Group group) {
    var node = TreeNode<Section>(key: UniqueKey().toString(), data: Section(name: group.name, icon: Icons.folder));

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

  void _makeGroupsBranch(List<Group> groups, TreeNode root) {

    // Order groups, so those that contain children (and are thus able to be opened) appear first
    groupOrder(List<Group> list) {
      return List.generate(list.length, (i) => i)
        ..sort((a, b) =>
            list[b].childrenCount().compareTo(list[a].childrenCount()));
    }

    makeGroupTreeBranch(group) {
      // Create current node, and recursively add it's children to the created node
      var node = TreeNode<Group>(key: UniqueKey().toString(), data: group);
      for (final int index in groupOrder(group.groups)) {
        node.add(makeGroupTreeBranch(group.groups[index]));
      }

      return node;
    }

    // Recursively all the groups (in their children) to the root
    for (final int index in groupOrder(groups)) {
      root.add(makeGroupTreeBranch(groups[index]));
    }

  }

  TreeNode _makeTree() {
    var root = TreeNode.root();

    var devices = TreeNode<Section>(key: UniqueKey().toString(), data: Section(name: "Dispositivos", icon: Icons.dns));
    var groups  = TreeNode<Section>(key: UniqueKey().toString(), data: Section(name: "Grupos", icon: Icons.folder));
    
    if (includeDevices) {
      for (Group group in topology.groups) {
        devices.add(_makeDeviceTreeBranch(group));
      }

      root.add(devices);
    }

    if (includeGroups) {
      _makeGroupsBranch(topology.groups, groups);

      root.add(groups);
    }

    return root;
  }

  Widget _makeTile(TreeNode node, WidgetRef ref) {

    String title = node.key;
    Widget text = Consumer(builder: (contex, ref, _)  {
      var _ = ref.watch(itemEditSelectionProvider);

      bool canBeDeleted = node.data is Device || node.data is Group;
      bool deleted = canBeDeleted ? ref.read(itemEditSelectionProvider.notifier).isDeleted(node.data) : false;
      Color backgroundColor = deleted ? deletedItemColor : Colors.transparent;

      return Text(title, style: TextStyle(backgroundColor: backgroundColor),);
    });

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
          title: text,
          visualDensity: VisualDensity(horizontal: -4, vertical: -4),
          leading: Padding(padding: iconPadding, child: node.icon,)
      );
  }

  Widget _makeTreeView(WidgetRef ref) {
    return TreeView.simple(
      tree: _makeTree(),
      showRootNode: showRoot,
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
      builder: (context, node) => _makeTile(node, ref),

      onItemTap: onItemTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {

      return UniversalDetector(
        setCursor: () => ref.read(itemEditSelectionProvider).creatingItem ? SystemMouseCursors.forbidden : SystemMouseCursors.click, 
        child: _makeTreeView(ref)
      );
    });
  }
}