import 'package:network_analytics/models/device.dart';

// TODO: Make generic, to also hold groups and links
class Group {
  final int id;
  final String name;
  final List<dynamic> members;
  final bool isDisplayGroup;

  Group({
    required this.id,
    required this.members,
    required this.name,
    required this.isDisplayGroup,
  });

  factory Group.fromJson(Map<String, dynamic> json, Map<int, dynamic> items) {
    List<Device> members = [];
    for (int device in json['members']) {
      members.add(items[device]);
    }

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
      members.add(Group.fromJson(group, items));
    }

    return members;
  }
}