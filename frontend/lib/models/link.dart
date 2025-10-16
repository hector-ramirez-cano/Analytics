import 'dart:math';

import 'package:flutter/material.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/theme/app_colors.dart';
import 'package:path_drawing/path_drawing.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/extensions/offset.dart';

class Link extends AnalyticsItem<Link> implements HoverTarget {
  final Device sideA;
  final Device sideB;
  final LinkType linkType;
  final String sideAIface;
  final String sideBIface;

  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_canvas_link_class_logging", false));

  late double A, B, C;

  // TODO: Add subtypes
  Link ({
    required super.id,
    required this.sideA,
    required this.sideB,
    required this.linkType,
    required this.sideAIface,
    required this.sideBIface,
  }) {

    // equation of a line given two points
    // m = (y2 - y1) / (x2 - x1) 
    double m = (sideB.position.dy - (sideA.position.dy + 0.0001)) / (sideB.position.dx - (sideA.position.dx + 0.0001));

    // equation of a line given a point and the slope
    // y - y1 = m (x - x1) 
    //
    // point-slope to general form
    // mx -  y + (y1-mx1) = 0
    // Ax + By + C        = 0
    A = m;
    B = -1;
    C = sideA.position.dy + 0.0001 - m * (sideA.position.dx + 0.0001);

    logger.d("A=$A, B=$B, C=$C");
    logger.d("sideA=${sideA.position}, sideB=${sideB.position}, m=$m");
  }

  Link copyWith({int? id, Device? sideA, Device? sideB, LinkType? linkType, String? sideAIface, String? sideBIface}) {
    return Link(id: id ?? this.id,
      sideA     : sideA ?? this.sideA,
      sideB     : sideB ?? this.sideB,
      linkType  : linkType ?? this.linkType,
      sideAIface: sideAIface ?? this.sideAIface,
      sideBIface: sideBIface ?? this.sideBIface
    ,);
  }

  @override
  Link mergeWith(Link other) {
    return other.copyWith();
  }

  factory Link.fromJson(Map<String, dynamic> json, Map<int, dynamic> devices) {
    Device sideA = devices[json['side-a'] as int];
    Device sideB = devices[json['side-b'] as int];
    String linkType = json['link-type'] as String;

    return Link(
      id   : json['id'] as int,
      sideA: sideA,
      sideB: sideB,
      linkType: LinkType.values.byName(linkType),
      sideAIface: json['side-a-iface'],
      sideBIface: json['side-b-iface'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'side-a': sideA.id,
      'side-b': sideB.id,
      'link-type': linkType.toString(),
      'side-a-iface': sideAIface,
      'side-b-iface': sideBIface,
    };
  }

  factory Link.emptyLink() {
    return Link(id: -1*Random(2).nextInt(10000), sideA: Device.emptyDevice(), sideB: Device.emptyDevice(), linkType: LinkType.copper, sideAIface: "", sideBIface: "");
  }

  static Set<Link> setFromJson(List<dynamic> json, Map<int, dynamic> devices) {
    Set<Link> links = {};
    for (var link in json) {
      links.add(Link.fromJson(link, devices));
    }
    
    return links;
  }

  @override
  bool isNewItem() {
    return id < 0;
  }

  double dist2(Offset point) {
    // distance point-line
    // d = | Axp + Byp + C |  / sqrt (A²+B²)
    // d²= ( Axp + Byp + C )² / (A² + B²)

    double numerator   = A * point.dx + B * point.dy + C;
    double denominator = A * A + B * B;
    
    logger.d("A=$A, B=$B, C=$C, Point=$point");
    logger.d("Numerator = $numerator, Denominator=$denominator");

    if (denominator == 0) return 10e23;

    return numerator * numerator / denominator;
  }

  bool isModifiedAIface(Topology topology) {
    return sideAIface != (topology.items[id] as Link?)?.sideAIface;
  }

  bool isModifiedBIface(Topology topology) {
    return sideBIface != (topology.items[id] as Link?)?.sideBIface;
  }

  @override
  bool hitTest(Offset point) {
    // checks whether the point is within the square bounding box of the line
    final withinBounds = dist2(point) < 0.0005;
    
    // Check bounding box overlap (i.e. P within X and Y bounds)
    final withinX = (point.dx - sideA.position.dx) * (point.dx - sideB.position.dx) <= 0.01;
    final withinY = (point.dy - sideA.position.dy) * (point.dy - sideB.position.dy) <= 0.01;

    logger.d("Hit test, withinBounds $withinBounds, withinX=$withinX, withinY=$withinY");

    return withinBounds && withinX && withinY;
  }

  @override
  int getId() {
    return id;
  }

  Path getPath(Size canvasSize, double scale, Offset centerOffset) {
    final start = sideA.position.globalToPixel(canvasSize, scale, centerOffset);
    final end   = sideB.position.globalToPixel(canvasSize, scale, centerOffset);
    final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);

    if (linkType == LinkType.wireless) {
        return dashPath(path, dashArray: CircularIntervalList([10, 5]));
    }

    return path;
  }

  Paint getPaint(ItemSelection? itemSelection) {
    if (itemSelection?.selected == getId()) {
      if (itemSelection?.forced == true) {
        return AppColors.selectedLinkPaint;
      }
      return AppColors.hoveringLinkPaint;
    }

    return AppColors.linkPaint;
  }

  @override
  bool operator ==(Object other) {
    return other is Link
    && id == other.id
    && linkType == other.linkType
    && sideA.id == other.sideA.id
    && sideB.id == other.sideB.id
    && sideAIface == other.sideAIface
    && sideBIface == other.sideBIface;
  }
  
  @override
  int get hashCode => super.hashCode;
  
}