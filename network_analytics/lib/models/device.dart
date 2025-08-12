import 'dart:ui';

import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/theme/app_colors.dart';

class Device implements HoverTarget {
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

  @override
  bool hitTest(Offset pointNDC) {
    return (pointNDC - positionNDC).distanceSquared <= 0.0001;
  }

  @override
  int getId() {
    return id;
  }

  Paint getPaint(Offset position, Size size) {
    final rect = Rect.fromCircle(center: position, radius: 6);

    return Paint()
      ..shader = AppColors.deviceGradient.createShader(rect);

  }
}
