import 'package:aegis/services/dashboard_service.dart';
import 'package:aegis/ui/components/universal_detector.dart';
import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:animated_tree_view/tree_view/tree_view.dart';
import 'package:animated_tree_view/tree_view/widgets/expansion_indicator.dart';
import 'package:animated_tree_view/tree_view/widgets/indent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardDrawer extends StatelessWidget {
  
  const DashboardDrawer({
    super.key,
    });

  void onChangeItem(WidgetRef ref, TreeNode value) {
    if (value is! TreeNode<DashboardLayout> || value.data == null) { return; }

    ref.read(dashboardSelectionProvider.notifier).setSelection((value).data!.id);
  }

    TreeNode _makeTree(WidgetRef ref) {
      var root = TreeNode.root();

      final dashboard = ref.watch(dashboardServiceProvider);

      return dashboard.when(
        error: (_, _) => root,
        loading: () => root,
        data: (dashboards) {
          for (final layout in dashboards.values) {
            final title = layout.name;
            final node = TreeNode(data: layout, key: "dashboard_side_drawer_$title");
            root.add(node);
          }

          return root;
        },
      );
    }

    Widget _makeTile(TreeNode node) {
      final string = node is TreeNode<DashboardLayout> ?  node.data?.name ?? "Sin nombre" : "Raíz";
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 8, 8),
        child: UniversalDetector(child: Text(string), setCursor: ()=>SystemMouseCursors.click,)
      );
    }

    Widget _makeTreeView(WidgetRef ref) {
    return TreeView.simple(
      tree: _makeTree(ref),
      showRootNode: true,
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

      onItemTap: (value) => onChangeItem(ref, value),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        return _makeTreeView(ref);
      },
    );
  }
}