import 'dart:ui';

extension RequireNotNullExtension<T> on T? {
  T require([String? label]) {
    if (this == null) {
      throw Exception('Missing required value${label != null ? ' for $label' : ''}');
    }
    return this as T;
  }
}



class Device {
  final int id;
  final String name;
  final Offset positionNDC;

  Device({
    required this.id,
    required this.positionNDC,
    required this.name,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id  : json['id'] as int,
      name: json['name'] as String,
      positionNDC: Offset(
        json['coordinates'][0] as double,
        json['coordinates'][1] as double,
      )
    );
  }

  static List<Device> listFromJson(List<dynamic> json) {
    List<Device> devices = [];

    for (var device in json) {
      devices.add(Device.fromJson(device));
    }

    return devices;
  }
}
