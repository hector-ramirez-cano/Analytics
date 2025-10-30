// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';

class Topology {
  Map<int, dynamic> items;
  Map<String, Device>? _deviceHostnames;

  Topology({
    required Map<int, dynamic> items,
  }) :  items = Map.unmodifiable(items);
  
  Topology copyWith({Map<int, dynamic>? items, List<Group>? groups}) {
    // update inner references
    
    final itemsMap = items ?? this.items;

    // Resolve new references into links for devices
    for (var entry in itemsMap.entries) {
      if (entry.value is! Link) continue;
      Link l = entry.value;
      Device sideA = itemsMap[l.sideA.id];
      Device sideB = itemsMap[l.sideB.id];
      l = l.copyWith(sideA: sideA, sideB: sideB);
      
      itemsMap[l.id] = l;
    }

    return Topology(items: itemsMap);
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

  factory Topology.empty() {
    return Topology(items: {});
  }


  Map<String, dynamic> toMap() {
    Map<String, dynamic> items = {};

    final groupMap = groups.map((group) => group.toMap()).toList();

    items['devices'] = devices.map((item) => item.toMap()).toList();
    items['links'] = links.map((link) => link.toMap()).toList();
    items['groups'] = groupMap;

    return items;
  }

  // TODO: Memoize
  Set<Device> get devices {
    return items.values.whereType<Device>().toSet();
  }

  // TODO: Memoize
  Set<Link> get links {
    return items.values.whereType<Link>().toSet();
  }

  // TODO: Memoize
  Set<Group> get groups {
    return items.values.whereType<Group>().toSet();
  }

  // TODO: Memoize
  Set<Link> getDeviceLinks(Device device) {
    return links.where((link) => link.sideA.id == device.id || link.sideB.id == device.id).toSet();
  }

  // TODO: Memoize
  Set<Group> getDeviceGroups(Device device) {
    return groups.where((group) => group.hasDevice(device)).toSet();
  }

  Map<String, Device> get deviceHostnames {
    _deviceHostnames ??= Map.fromEntries(devices.map((device) => MapEntry(device.mgmtHostname, device)));

    return _deviceHostnames!;
  }

  // TODO: Memoize
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

  Device? getDeviceByHostname(String hostname) {
    return deviceHostnames[hostname];
  }

  
}