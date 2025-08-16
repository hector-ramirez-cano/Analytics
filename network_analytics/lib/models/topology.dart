// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/device_group.dart';
import 'package:network_analytics/models/link.dart';

class Topology {
  Map<int, dynamic> items;
  List<DeviceGroup> groups;

  Topology({
    required this.items,
    required this.groups,
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

    List<DeviceGroup> groups = DeviceGroup.deviceGroupFromJson(json['groups'], itemsLocal);

    return Topology(items: itemsLocal, groups: groups);
  }

  List<Device> getDevices() {
    return items.values.whereType<Device>().toList();
  }

  List<Link> getLinks() {
    return items.values.whereType<Link>().toList();
  }
}