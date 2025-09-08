import 'dart:ui';

import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/theme/app_colors.dart';

class Device implements HoverTarget {
  final int id;
  final String name;
  final Offset position;    // x, y
  final Offset geoPosition; // Lat , Long
  final String mgmtHostname;

  final Set<String> requestedMetadata;
  final Set<String> requestedMetrics;
  final Set<String> availableValues;

  Device({
    required this.id,
    required this.position,
    required this.name,
    required this.geoPosition,
    required this.mgmtHostname,
    required Set<String> requestedMetadata,
    required Set<String> requestedMetrics,
    required Set<String> availableValues,
    
  }): 
    requestedMetadata = Set.unmodifiable(requestedMetadata),
    requestedMetrics = Set.unmodifiable(requestedMetrics),
    availableValues = Set.unmodifiable(availableValues);

  Device cloneWith({int? id, Offset? position, String? name, Offset? geoPosition, String? mgmtHostname, Set? requestedMetadata, Set? requestedMetrics, Set? availableValues}) {
    return Device(
      id               : id ?? this.id,
      position         : position ?? this.position,
      name             : name ?? this.name,
      geoPosition      : geoPosition ?? this.geoPosition,
      mgmtHostname     : mgmtHostname ?? this.mgmtHostname,
      requestedMetadata: Set.from(requestedMetadata ?? this.requestedMetadata),
      requestedMetrics : Set.from(requestedMetrics ?? this.requestedMetrics),
      availableValues  : Set.from(availableValues ?? this.availableValues),
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id  : json['id'] as int,
      name: json['name'] as String,
      position: Offset(
        json['coordinates'][0] as double,
        json['coordinates'][1] as double,
      ),
      geoPosition: Offset(
        json['geocoordinates'][0] as double,
        json['geocoordinates'][1] as double,
      ),
      mgmtHostname: json['management-hostname'],
      requestedMetadata: Set<String>.from(json['configuration']['requested-metadata']),
      requestedMetrics:  Set<String>.from(json['configuration']['requested-metrics']),
      availableValues:   Set<String>.from(json['configuration']['available-values']),
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
  bool hitTest(Offset point) {
    return (point - position).distanceSquared <= 0.0001;
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
