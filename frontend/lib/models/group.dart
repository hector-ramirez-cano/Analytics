
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

  Group({
    required this.id,
    required this.members,
    required this.name,
    required this.isDisplayGroup,
  });
  

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

  static List<Group> deviceGroupFromJson(List<dynamic> json, Map<int, dynamic> items) {
    List<Group> members = [];

    for (var group in json) {
      var created = Group.fromJson(group, items);
      members.add(created);
      items[created.id] = created;
    }

    return members;
  }

  static void fillGroupMembers(List<dynamic> json, Map<int, dynamic> items) {
    for (var group in json) {
      int id = group["id"];
      
      for (var member in group['members']) {
        (items[id] as Group).members.add(items[member]);
      }
    }
  }

  bool hasDevices() {
    return devices.isNotEmpty || groups.any((group) => group.hasDevices());
  }

  num childrenCount() {
    return members.length +
      groups.fold<num>(0, (sum, group) => sum + group.childrenCount());
  }
}