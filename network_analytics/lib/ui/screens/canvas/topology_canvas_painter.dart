import 'package:flutter/material.dart';
import 'package:network_analytics/services/hover_interaction_service.dart';

import 'package:path_drawing/path_drawing.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/theme/app_colors.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/screens/canvas/topology_canvas.dart';


class TopologyCanvasPainter extends CustomPainter {
  Topology topology;
  CanvasInteractionService canvasInteractionService;
  
  final int? itemSelection;
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
      final rect = Rect.fromCircle(center: position, radius: 6);

      final Paint devicePaint = Paint()
        ..shader = AppColors.deviceGradient.createShader(rect);

      canvas.drawCircle(position, 6, devicePaint);
    }
  }

  void _paintLinks(Canvas canvas, Size size) {
    for (var link in topology.getLinks()) {
      final start = link.sideA.positionNDC.ndcToPixel(size);
      final end   = link.sideB.positionNDC.ndcToPixel(size);

      final Paint linkPaint = (itemSelection == link.getId()) ? AppColors.selectedLinkPaint : AppColors.linkPaint;

      if (link.linkType == LinkType.wireless) {
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);

        final dashed = dashPath(path, dashArray: CircularIntervalList([10, 5]));
        canvas.drawPath(dashed, linkPaint);
      } else {
        canvas.drawLine(start, end, linkPaint);
      }
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
    
    // TODO: Fix border
    // Draw border
    // canvas.drawRect(
    //   Rect.fromLTWH(0, 0, size.width, size.height),
    //   AppColors.canvasBorderPaint,
    // );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
