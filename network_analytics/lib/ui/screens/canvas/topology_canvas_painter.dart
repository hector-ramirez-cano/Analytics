import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';

import 'package:network_analytics/theme/app_colors.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/extensions/offset.dart';

class TopologyCanvasPainter extends CustomPainter {
  Topology topology;
  CanvasInteractionService canvasInteractionService;
  
  final ItemSelection? itemSelection;
  final void Function(Size) onSizeChanged;

  TopologyCanvasPainter({
    required this.topology,
    required this.canvasInteractionService,
    required this.itemSelection,
    required this.onSizeChanged,
  });

  void _paintDevices(Canvas canvas, Size size) {
    for (var device in topology.getDevices()) {
      final position = device.positionNDC.ndcToPixel(size);
      final devicePaint = device.getPaint(position, size);
      double radius = 6;

      if (canvasInteractionService.hovered?.getId() == device.getId()) {
        // Logger().d("Painting shadow"); 
        radius = 10;
      }

      canvas.drawCircle(position, radius, devicePaint);
    }
  }

  void _paintLinks(Canvas canvas, Size size) {
    for (var link in topology.getLinks()) {
      
      final Paint linkPaint = link.getPaint(itemSelection);
      final path = link.getPath(size);

      if (itemSelection?.selected == link.getId()) {
        canvas.drawPath(path, AppColors.linkShadowPaint);
      } 

      canvas.drawPath(path, linkPaint);
      
    }
  }

  void _registerHoverItems() {
    canvasInteractionService.clearTargets();
    
    topology.getDevices().forEach((device) => canvasInteractionService.registerTarget(device));
    topology.getLinks().forEach((link) => canvasInteractionService.registerTarget(link));
  }

  @override
  void paint(Canvas canvas, Size size) {
    onSizeChanged(size);

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.grey.shade200, // TODO: Change to app color
    );

    _registerHoverItems();
    _paintLinks(canvas, size);
    _paintDevices(canvas, size);
    
    // Draw border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      AppColors.canvasBorderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
