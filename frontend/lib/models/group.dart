
// TODO: Make generic, to also hold groups and links
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';

class Group {
  final int id;
  final String name;
  final List<dynamic> members;
  final bool isDisplayGroup;

  late final int groupCount       = members.whereType<Group>().toList().length;
  late final List<Device> devices = members.whereType<Device>().toList();
  late final List<Group> groups   = members.whereType<Group>().toList();
  late final List<Link> links     = members.whereType<Link>().toList(); 
  late final Set<int> memberKeys  = members.map((member) => member.id as int).toSet();

  Group({
    required this.id,
    required this.members,
    required this.name,
    required this.isDisplayGroup,
  });
  
  Group cloneWith({int? id, String? name, List<dynamic>? members, bool? isDisplayGroup}) {
    return Group(id: id ?? this.id, members: members ?? this.members, name: name ?? this.name, isDisplayGroup: isDisplayGroup ?? this.isDisplayGroup);
  }

  factory Group.fromJson(Map<String, dynamic> json, Map<int, dynamic> items) {
    List<dynamic> members = [];

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

  /// Creates a list of groups from a given [json] array. Queries the items from an [items] map of {int -> dynamic}
  static List<Group> deviceGroupFromJson(List<dynamic> json, Map<int, dynamic> items) {
    List<Group> members = [];

    for (var group in json) {
      var created = Group.fromJson(group, items);
      members.add(created);
      items[created.id] = created;
    }

    return members;
  }

  /// Populates the members of a group, with a given [json] array. Queries the items from an [items] map of {int -> dynamic}
  static void fillGroupMembers(List<dynamic> json, Map<int, dynamic> items) {
    for (var group in json) {
      int id = group["id"];
      
      for (var member in group['members']) {
        (items[id] as Group).members.add(items[member]);
      }
    }
  }

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

  @override
  String toString() {
    return members.map((member) => {
      if (member is Device) { member.name }
      else if (member is Group) { member.name }
      else ""
    }).toList().toString();
  }
}