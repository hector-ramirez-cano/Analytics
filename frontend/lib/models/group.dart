import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';

class Group extends GroupableItem<Group>{
  final Set<GroupableItem> members;
  final bool isDisplayGroup;

  Group({
    required super.id,
    required super.name,
    required members,
    required this.isDisplayGroup,
  })
    : members = Set.unmodifiable(members);
  
  Group copyWith({int? id, String? name, Set<GroupableItem>? members, bool? isDisplayGroup}) {
    return Group(
      id: id ?? this.id,
      members: Set<GroupableItem>.from(members ?? this.members),
      name: name ?? this.name,
      isDisplayGroup: isDisplayGroup ?? this.isDisplayGroup
    );
  }

  @override
  Group mergeWith(Group other) {
    var members = Set<GroupableItem>.from(other.members)..addAll(this.members);

    return copyWith(members: members);
  }

  factory Group.fromJson(Map<String, dynamic> json, Map<int, dynamic> items) {
    List<GroupableItem> members = [];

    int    id   = json['id'];
    String name = json['name'];
    bool   isDisplayGroup = json['is-display-group'];

    return Group(
      id: id, 
      members: members,
      name: name, 
      isDisplayGroup: isDisplayGroup
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is-display-group': isDisplayGroup,
      'members': members.map((member) => member.id).toList()
    };
  }

  factory Group.empty() {
    return Group(id: -1*Random(2).nextInt(10000), members: <GroupableItem>{}, name: "", isDisplayGroup: false);
  }

  /// Creates a list of groups from a given [json] array. Queries the items from an [items] map of {int -> dynamic}
  static void deviceGroupFromJson(List<dynamic> json, Map<int, dynamic> items) {
    for (var group in json) {
      var created = Group.fromJson(group, items);
      items[created.id] = created;
    }
  }

  /// Populates the members of a group, with a given [json] array. Queries the items from an [items] map of {int -> dynamic}
  static void fillGroupMembers(List<dynamic> json, Map<int, dynamic> items) {
    for (var group in json) {
      int id = group["id"];
      
      var members = <GroupableItem>{};
      var oldMembers = (items[id] as Group).members;
      for (var id in group['members']) {
        members.add(items[id]);
      }

      items[id] = (items[id] as Group).copyWith(members: {...oldMembers, ...members});
    }
  }

  int          get groupCount  => members.whereType<Group>().toList().length;
  Set<Device>  get devices     => members.whereType<Device>().toSet();
  Set<Group>   get groups      => members.whereType<Group>().toSet();
  Set<Link>    get links       => members.whereType<Link>().toSet(); 
  Set<int>     get memberKeys  => members.map((member) => member.id).toSet();
  Set<Device>  get allDescendants => Set.from({...devices, ...groups.map((inner) => inner.allDescendants).toSet()});

  /// Returns whether this group, or any nested groups contain at least one device. Short circuits once at least one is found
  bool hasDevices() {
    return devices.isNotEmpty || groups.any((group) => group.hasDevices());
  }

  /// Looks for the device in this group, or any nested groups by ID, regardless of whether the instance is the same.
  bool hasDevice(Device device) {
    // O(n), but can't use raw container 'contains', because instances might be different, but the same id
    return devices.any((dev) => dev.id == device.id) || groups.any((group) => group.hasDevice(device));
  }

  /// Returns the count of children only in this group
  num childrenCount() {
    return members.length +
      groups.fold<num>(0, (sum, group) => sum + group.childrenCount());
  }

  bool isModifiedName(Topology topology) {
    
    return name != (topology.items[id] as Group?)?.name;
  }

  @override
  bool isNewItem() {
    return id < 0;
  }

  @override
  String toString() {
    return members.map((member) => {
      if (member is Device) { member.name }
      else if (member is Group) { member.name }
      else ""
    }).toList().toString();
  }

  @override
  bool operator ==(Object other) {
    return other is Group
    && (other as GroupableItem) == (this as GroupableItem)
    && isDisplayGroup == other.isDisplayGroup
    && setEquals(members, other.members);
  }
}