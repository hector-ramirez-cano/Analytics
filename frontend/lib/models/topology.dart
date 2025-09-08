// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';

class Topology {
  Map<int, dynamic> items;
  List<Group> groups;

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

    List<Group> groups = Group.deviceGroupFromJson(json['groups'], itemsLocal);
    Group.fillGroupMembers(json['groups'], itemsLocal);

    return Topology(items: itemsLocal, groups: groups);
  }

  List<Device> getDevices() {
    return items.values.whereType<Device>().toList();
  }

  List<Link> getLinks() {
    return items.values.whereType<Link>().toList();
  }

  List<Group> getGroups() {
    return items.values.whereType<Group>().toList();
  }

  List<Link> getDeviceLinks(Device device) {
    return getLinks().where((link) => link.sideA.id == device.id || link.sideB.id == device.id).toList();
  }

  List<Group> getDeviceGroups(Device device) {
    return getGroups().where((group) => group.hasDevice(device)).toList();
  }
}