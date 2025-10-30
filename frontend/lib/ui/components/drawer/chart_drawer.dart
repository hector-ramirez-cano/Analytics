import 'package:flutter/widgets.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/ui/components/item_tree.dart';

class ChartDrawer extends StatelessWidget {

  final Topology topology;

  const ChartDrawer({super.key, required this.topology});
  
  @override
  Widget build(BuildContext context) {
    return ItemTree(topology: topology, includeDevices: true, includeGroups: false, onItemTap: (_) => {},); // TODO: Functionality
  }
}