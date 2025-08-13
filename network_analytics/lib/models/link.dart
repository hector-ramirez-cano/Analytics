import 'package:flutter/material.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/theme/app_colors.dart';
import 'package:path_drawing/path_drawing.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/extensions/offset.dart';

class Link implements HoverTarget {
  final int id;
  final Device sideA;
  final Device sideB;
  final LinkType linkType;

  late double A, B, C;

  Link ({
    required this.id,
    required this.sideA,
    required this.sideB,
    required this.linkType
  })
    
  {

    // equation of a line given two points
    // m = (y2 - y1) / (x2 - x1) 
    double m = (sideB.positionNDC.dy - (sideA.positionNDC.dy + 0.0001)) / (sideB.positionNDC.dx - (sideA.positionNDC.dx + 0.0001));

    // equation of a line given a point and the slope
    // y - y1 = m (x - x1) 
    //
    // point-slope to general form
    // mx -  y + (y1-mx1) = 0
    // Ax + By + C        = 0
    A = m;
    B = -1;
    C = sideA.positionNDC.dy + 0.0001 - m * (sideA.positionNDC.dx + 0.0001);

    Logger().d("A=$A, B=$B, C=$C");
    Logger().d("sideA=${sideA.positionNDC}, sideB=${sideB.positionNDC}, m=$m");
  }

  factory Link.fromJson(Map<String, dynamic> json, Map<int, dynamic> devices) {
    Device sideA = devices[json['side-a'] as int];
    Device sideB = devices[json['side-b'] as int];
    String linkType = json['link-type'] as String;

    return Link(
      id   : json['id'] as int,
      sideA: sideA,
      sideB: sideB,
      linkType: LinkType.values.byName(linkType)
    );
  }

  static List<Link> listFromJson(List<dynamic> json, Map<int, dynamic> devices) {
    List<Link> links = [];
    for (var link in json) {
      links.add(Link.fromJson(link, devices));
    }
    
    return links;
  }

  double dist2(Offset pointNDC) {
    // distance point-line
    // d = | Axp + Byp + C |  / sqrt (A²+B²)
    // d²= ( Axp + Byp + C )² / (A² + B²)

    double numerator   = A * pointNDC.dx + B * pointNDC.dy + C;
    double denominator = A * A + B * B;
    
    // Logger().d("A=$A, B=$B, C=$C, Point=$pointNDC");
    // Logger().d("Numerator = $numerator, Denominator=$denominator");

    if (denominator == 0) return 10e23;

    return numerator * numerator / denominator;
  }

  @override
  bool hitTest(Offset pointNDC) {
    // checks whether the point is within the square bounding box of the line
    final withinBounds = dist2(pointNDC) < 0.0005;
    
    // Check bounding box overlap (i.e. P within X and Y bounds)
    final withinX = (pointNDC.dx - sideA.positionNDC.dx) * (pointNDC.dx - sideB.positionNDC.dx) <= 0.01;
    final withinY = (pointNDC.dy - sideA.positionNDC.dy) * (pointNDC.dy - sideB.positionNDC.dy) <= 0.01;

    // Logger().d("Hit test, withinBounds $withinBounds, withinX=$withinX, withinY=$withinY, dist2=$dist");

    return withinBounds && withinX && withinY;
  }

  @override
  int getId() {
    return id;
  }


  Path getPath(Size size) {
    final start = sideA.positionNDC.ndcToPixel(size);
    final end   = sideB.positionNDC.ndcToPixel(size);
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

  
}