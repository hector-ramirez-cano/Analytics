// ignore: unused_import
import 'package:logger/web.dart';
import 'package:aegis/models/analytics_item.dart';
import 'package:aegis/models/device.dart';
import 'package:aegis/models/group.dart';
import 'package:aegis/models/link.dart';

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

  Set<Device>? _devicesCache;
  Set<Device> get devices {
    _devicesCache ??= items.values.whereType<Device>().toSet();
    return _devicesCache!;
  }

  Set<Link>? _linksCache;
  Set<Link> get links {
    _linksCache ??= items.values.whereType<Link>().toSet();

    return _linksCache!;
  }

  Set<Group>? _groups;
  Set<Group> get groups {
    _groups ??= items.values.whereType<Group>().toSet();

    return _groups!;
  }

  final Map<int, Set<Link>> _deviceLinksCache = {};
  Set<Link> getDeviceLinks(Device device) {
    if (!_deviceLinksCache.containsKey(device.id)) {
      _deviceLinksCache[device.id] = links.where((link) => link.sideA.id == device.id || link.sideB.id == device.id).toSet();
    }

    return _deviceLinksCache[device.id]!;
  }

  final Map<int, Set<Group>> _deviceGroupsCache = {};
  Set<Group> getDeviceGroups(Device device) {
    if (!_deviceGroupsCache.containsKey(device.id)) {
      _deviceGroupsCache[device.id] = groups.where((group) => group.hasDevice(device)).toSet();
    }
    return _deviceGroupsCache[device.id]!;
  }

  Set<Device> get ungroupedDevices {
    return devices.where((d) { return getDeviceGroups(d).isEmpty; }).toSet();
  }

  Map<String, Device> get deviceHostnames {
    _deviceHostnames ??= Map.fromEntries(devices.map((device) => MapEntry(device.mgmtHostname, device)));

    return _deviceHostnames!;
  }

  final Map<int, Set<String>> _allAvailableValuesCache = {};
  Set<String> getAllAvailableValues(GroupableItem item) {
    if (!_allAvailableValuesCache.containsKey(item.id)) {
      if (item is Device) {
        _allAvailableValuesCache[item.id] = item.availableValues;
      }
      else if (item is Group) {
        final values = item.allDescendants.map((device) => getAllAvailableValues(device));
        _allAvailableValuesCache[item.id] = values.expand((inner) => inner).toSet();
      }
      else {
        throw Exception("Unexpected type for gathering all available values");
      }
    }

    return _allAvailableValuesCache[item.id]!;
  }

  Device? getDeviceByHostname(String hostname) {
    return deviceHostnames[hostname];
  }

  
}