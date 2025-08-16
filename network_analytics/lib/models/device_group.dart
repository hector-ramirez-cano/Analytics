import 'package:network_analytics/models/device.dart';

class DeviceGroup {
  final int id;
  final String name;
  final List<Device> devices;
  final bool isDisplayGroup;

  DeviceGroup({
    required this.id,
    required this.devices,
    required this.name,
    required this.isDisplayGroup,
  });

  factory DeviceGroup.fromJson(Map<String, dynamic> json, Map<int, dynamic> items) {
    List<Device> devices = [];
    for (int device in json['members']) {
      devices.add(items[device]);
    }

    int    id   = json['id'];
    String name = json['name'];
    bool   isDisplayGroup = json['displayGroup'];

    return DeviceGroup(
      id: id, 
      devices: devices, 
      name: name, 
      isDisplayGroup: isDisplayGroup
    );
  }

  static List<DeviceGroup> deviceGroupFromJson(List<dynamic> json, Map<int, dynamic> items) {
    List<DeviceGroup> devices = [];

    for (var group in json) {
      devices.add(DeviceGroup.fromJson(group, items));
    }

    return devices;
  }
}