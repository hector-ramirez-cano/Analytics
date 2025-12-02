import 'package:aegis/models/device.dart';
import 'package:aegis/models/link.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/models/topology_view/topology_view_template.dart';

class TopologyView {
  final TopologyViewTemplate template;
  final Topology topology;

  Set<Device>? _devices;
  Set<Link>? _links;

  TopologyView({
    required this.template,
    required this.topology
  });

  TopologyView copyWith({Topology? topology, TopologyViewTemplate? template}) {
    return TopologyView(template: template ?? this.template, topology: topology ?? this.topology);
  }

  // TODO: Memoize
  Set<Device> get devices {
    _devices = topology.devices.where((Device d) => template.members.containsKey(d.id)).toSet();

    return _devices!;
  }

  // TODO: Memoize
  Set<Link> get links {
    _links = topology.links.where((Link link) => devices.contains(link.sideA) || devices.contains(link.sideB)).toSet();

    return  _links!;
  }
}