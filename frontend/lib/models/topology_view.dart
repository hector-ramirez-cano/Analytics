import 'package:network_analytics/models/topology.dart';

class TopologyView extends Topology {
  final Set<int> filter;

  TopologyView({
    required this.filter,
    required super.items,
    required super.groups,
  });

  List<T> get<T>() {
    List<T> items = [];

    for (var entry in this.items.entries) {
      if (entry.value is T && filter.contains(entry.key))  {
        items.add(entry.value);
      }
    }

    return items;
  }

  factory TopologyView.fromTopology(Topology topology, Set<int> filter) {
    return TopologyView(filter: filter, items: topology.items, groups: topology.groups);
  }
}