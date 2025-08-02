import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';

class Topology {
  Map<int, dynamic> items;

  Topology({
    required this.items,
  });

  factory Topology.fromJson(Map<String, dynamic> json) {
    Map<int, dynamic> itemsLocal = {};

    List<Device> devices = Device.listFromJson(json['devices']);
    for (var device in devices) {
      itemsLocal[device.id] = device;
    }

    List<Link> links = Link.listFromJson(json['links'], itemsLocal);
    for (var link in links) {
      itemsLocal[link.id] = link;
    }

    return Topology(items: itemsLocal);
  }

}