import 'dart:ui';

import 'package:free_map/free_map.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/theme/app_colors.dart';

class Device extends GroupableItem<Device> implements HoverTarget{
  final Offset position;    // x, y
  final LatLng geoPosition; // Lat , Long
  final String mgmtHostname;

  final Set<String> requestedMetadata;
  final Set<String> requestedMetrics;
  final Set<String> availableValues;
  final Set<String> dataSources;

  Device({
    required super.id,
    required super.name,
    required this.position,
    required this.geoPosition,
    required this.mgmtHostname,
    required Set<String> requestedMetadata,
    required Set<String> requestedMetrics,
    required Set<String> availableValues,
    required Set<String> dataSources,
    
  }): 
    requestedMetadata = Set.unmodifiable(requestedMetadata),
    requestedMetrics = Set.unmodifiable(requestedMetrics),
    availableValues = Set.unmodifiable(availableValues),
    dataSources = Set.unmodifiable(dataSources);

  Device cloneWith({
    int? id,
    Offset? position,
    String? name,
    LatLng? geoPosition,
    String? mgmtHostname,
    Set? requestedMetadata,
    Set? requestedMetrics,
    Set? availableValues,
    Set? dataSources,
  }) {
    return Device(
      id               : id ?? this.id,
      position         : position ?? this.position,
      name             : name ?? this.name,
      geoPosition      : geoPosition ?? this.geoPosition,
      mgmtHostname     : mgmtHostname ?? this.mgmtHostname,
      requestedMetadata: Set.from(requestedMetadata ?? this.requestedMetadata),
      requestedMetrics : Set.from(requestedMetrics ?? this.requestedMetrics),
      availableValues  : Set.from(availableValues ?? this.availableValues),
      dataSources      : Set.from(dataSources ?? this.dataSources),
    );
  }

  @override
  Device mergeWith(Device other){
    var requestedMetadata = Set.from(other.requestedMetadata)..addAll(this.requestedMetadata);
    var requestedMetrics  = Set.from(other.requestedMetrics )..addAll(this.requestedMetrics );
    var availableValues   = Set.from(other.availableValues  )..addAll(this.availableValues  );
    var dataSources       = Set.from(other.dataSources      )..addAll(this.dataSources      );

    return cloneWith(
      requestedMetadata: requestedMetadata, 
      requestedMetrics : requestedMetrics,  
      availableValues  : availableValues,   
      dataSources      : dataSources,       
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
      geoPosition: LatLng(
        json['geocoordinates'][0] as double,
        json['geocoordinates'][1] as double,
      ),
      mgmtHostname: json['management-hostname'],
      requestedMetadata: Set<String>.from(json['configuration']['requested-metadata']),
      requestedMetrics:  Set<String>.from(json['configuration']['requested-metrics']),
      availableValues:   Set<String>.from(json['configuration']['available-values']),
      dataSources:       Set<String>.from(json['configuration']['data-sources']),
    );
  }

  factory Device.emptyDevice(){
    return Device(
      id: -1,
      position: Offset.zero,
      name: "Nuevo Dispositivo",
      geoPosition: LatLng(0, 0),
      mgmtHostname: "",
      requestedMetadata: {},
      requestedMetrics: {},
      availableValues: {},
      dataSources: {}
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


  /// Returns whether a given [metric] is modified in the current instance, in reference to the original [topology]
  bool isModifiedMetric(String metric, Topology topology) {
    return requestedMetrics.contains(metric) != (topology.items[id] as Device?)?.requestedMetrics.contains(metric);
  }

  /// Returns whether a given [metric] is deleted in the current instance, aka is not found on the instance, but found on the original [topology]
  bool isDeletedMetric(String metric, Topology topology) {
    return !requestedMetrics.contains(metric) && (topology.items[id] as Device?)?.requestedMetrics.contains(metric) == true;
  }

  /// Returns whether a given [metadata] is modified in the current instance, in reference to the original [topology]
  bool isModifiedMetadata(String metadata, Topology topology) {
    return requestedMetadata.contains(metadata) != (topology.items[id] as Device?)?.requestedMetadata.contains(metadata);
  }

  /// Returns whether a given [metadata] is deleted in the current instance, aka is not found on the instance, but found on the original [topology]
  bool isDeletedMetadata(String metadata, Topology topology) {
    return !requestedMetadata.contains(metadata) && (topology.items[id] as Device?)?.requestedMetadata.contains(metadata) == true;
  }

  /// Returns whether a given [dataSource] is modified in the current instance, in reference to the original [topology]
  bool isModifiedDataSources(String dataSource, Topology topology) {
    return dataSources.contains(dataSource) != (topology.items[id] as Device?)?.dataSources.contains(dataSource);
  }

  /// Returns whether a given [dataSource] is deleted in the current instance, aka is not found on the instance, but found on the original [topology]
  bool isDeletedDataSource(String dataSource, Topology topology) {
    return !dataSources.contains(dataSource) && (topology.items[id] as Device?)?.dataSources.contains(dataSource) == true;
  }

  bool isModifiedName(Topology topology) {
    if (!topology.items.containsKey(id)) {
      return false;
    }

    return name != (topology.items[id] as Device?)?.name;
  }

  bool isModifiedHostname(Topology topology) {
    if (!topology.items.containsKey(id)) {
      return false;
    }

    return mgmtHostname != (topology.items[id] as Device?)?.mgmtHostname;
  }

  bool isModifiedGeoLocation(Topology topology) {
    if (!topology.items.containsKey(id)) {
      return false;
    }
    return geoPosition != (topology.items[id] as Device?)?.geoPosition; 
  }

  bool isModifiedPosition(Topology topology) {
    if (!topology.items.containsKey(id)) {
      return false;
    }
    return position != (topology.items[id] as Device?)?.position; 
  }
}
