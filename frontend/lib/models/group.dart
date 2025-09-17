import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';

class Group extends AnalyticsItem<Group>{
  final String name;
  final Set<dynamic> members;
  final bool isDisplayGroup;

  Group({
    required super.id,
    required members,
    required this.name,
    required this.isDisplayGroup,
  })
    : members = Set.unmodifiable(members);
  
  Group cloneWith({int? id, String? name, Set<dynamic>? members, bool? isDisplayGroup}) {
    return Group(
      id: id ?? this.id,
      members: Set.from(members ?? this.members),
      name: name ?? this.name,
      isDisplayGroup: isDisplayGroup ?? this.isDisplayGroup
    );
  }

  @override
  Group mergeWith(Group other) {
    var members = Set.from(other.members)..addAll(this.members);

    return cloneWith(members: members);
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

  factory Group.emptyGroup() {
    return Group(id: -1, members: [], name: "", isDisplayGroup: false);
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
      
      var members = [];
      var oldMembers = (items[id] as Group).members;
      for (var member in group['members']) {
        members.add(items[member]);
      }

      items[id] = (items[id] as Group).cloneWith(members: {...oldMembers, ...members});
    }
  }

  int          get groupCount  => members.whereType<Group>().toList().length;
  List<Device> get devices     => members.whereType<Device>().toList();
  List<Group>  get groups      => members.whereType<Group>().toList();
  List<Link>   get links       => members.whereType<Link>().toList(); 
  Set<int>     get memberKeys  => members.map((member) => member.id as int).toSet();

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
  String toString() {
    return members.map((member) => {
      if (member is Device) { member.name }
      else if (member is Group) { member.name }
      else ""
    }).toList().toString();
  }
}