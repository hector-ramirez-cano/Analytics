import 'package:network_analytics/models/topology.dart';

class TopologyView {
  final Topology topology;
  final Set<int> filter;

  TopologyView({
    required this.topology,
    required this.filter,
  });

  List<T> get<T>() {
    List<T> items = [];

    for (var entry in topology.items.entries) {
      if (entry.value is T && filter.contains(entry.key))  {
        items.add(entry.value);
      }
    }

    return items;
  }
}