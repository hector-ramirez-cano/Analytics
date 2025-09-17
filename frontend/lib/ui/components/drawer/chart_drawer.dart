import 'package:flutter/widgets.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/topology_tree.dart';

class ChartDrawer extends StatelessWidget {

  final Topology topology;

  const ChartDrawer({super.key, required this.topology});
  
  @override
  Widget build(BuildContext context) {
    return TopologyTree(topology: topology, includeDevices: true, includeGroups: false, onItemTap: (_) => {},); // TODO: Functionality
  }
}