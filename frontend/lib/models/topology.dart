// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';

class Topology {
  Map<int, dynamic> items;

  Topology({
    required Map<int, dynamic> items,
  }) : items = Map.unmodifiable(items);

  Topology copyWith({Map<int, dynamic>? items, List<Group>? groups}) {
    return Topology(items: items ?? this.items);
  }

  factory Topology.fromJson(Map<String, dynamic> json) {
    Map<int, dynamic> itemsLocal = {};

    Set<Device> devices = Device.setFromJson(json['devices']);
    for (var device in devices) {
      itemsLocal[device.id] = device;
    }

    Set<Link> links = Link.setFromJson(json['links'], itemsLocal);
    for (var link in links) {
      itemsLocal[link.id] = link;
    }

    Group.deviceGroupFromJson(json['groups'], itemsLocal);
    Group.fillGroupMembers(json['groups'], itemsLocal);

    return Topology(items: itemsLocal);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> items = {};

    final groupMap = groups.map((group) => group.toMap()).toList();

    items['devices'] = devices.map((item) => item.toMap()).toList();
    items['links'] = links.map((link) => link.toMap()).toList();
    items['groups'] = groupMap;

    return items;
  }

  Set<Device> get devices {
    return items.values.whereType<Device>().toSet();
  }

  Set<Link> get links {
    return items.values.whereType<Link>().toSet();
  }

  Set<Group> get groups {
    return items.values.whereType<Group>().toSet();
  }

  Set<Link> getDeviceLinks(Device device) {
    return links.where((link) => link.sideA.id == device.id || link.sideB.id == device.id).toSet();
  }

  Set<Group> getDeviceGroups(Device device) {
    return groups.where((group) => group.hasDevice(device)).toSet();
  }

  Set<String> getAllAvailableValues(GroupableItem item) {
    if (item is Device) {
      return item.availableValues;
    }

    if (item is Group) {
      final values = item.allDescendants.map((device) => getAllAvailableValues(device));
      return values.expand((inner) => inner).toSet();
    }

    else {
      throw Exception("Unexpected type for gathering all available values");
    }
  }
}