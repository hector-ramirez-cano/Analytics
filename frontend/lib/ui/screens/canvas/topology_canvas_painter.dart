import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/services/canvas_state_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';

import 'package:network_analytics/theme/app_colors.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/extensions/offset.dart';

class TopologyCanvasPainter extends CustomPainter {
  Topology topology;
  CanvasInteractionService canvasInteractionService;
  CanvasState canvasState;

  final ItemSelection? itemSelection;
  final CanvasStateChangedCallback onCanvasStateChanged;
  final CanvasSizeChangedCallback onSizeChanged;

  TopologyCanvasPainter({
    required this.topology,
    required this.canvasInteractionService,
    required this.canvasState,
    required this.itemSelection,
    required this.onCanvasStateChanged,
    required this.onSizeChanged,
  });

  void _paintDevices(Canvas canvas, Size size) {

    double scale = canvasState.scale;
    Offset centerOffset = canvasState.centerOffset;

    for (var device in topology.devices) {
      final position = device.position.globalToPixel(size, scale, centerOffset);
      final devicePaint = device.getPaint(position, size);
      double radius = 6;

      if (canvasInteractionService.hovered?.getId() == device.getId()) {
        radius = 10;
      }

      canvas.drawCircle(position, radius, devicePaint);
    }
  }

  void _paintLinks(Canvas canvas, Size size) {
    double scale = canvasState.scale;
    Offset centerOffset = canvasState.centerOffset;

    for (var link in topology.links) {

      final Paint linkPaint = link.getPaint(itemSelection);
      final path = link.getPath(size, scale, centerOffset);

      if (itemSelection?.selected == link.getId()) {
        canvas.drawPath(path, AppColors.linkShadowPaint);
      }

      canvas.drawPath(path, linkPaint);

    }
  }

  void _registerHoverItems() {
    canvasInteractionService.clearTargets();

    topology.devices.forEach((device) => canvasInteractionService.registerTarget(device));
    topology.links.forEach((link) => canvasInteractionService.registerTarget(link));
  }

  @override
  void paint(Canvas canvas, Size size) {
    onSizeChanged(size);
    canvas.clipRect(Offset.zero & size);

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

  // TODO: Optimization: Make it so it only repaints if either selection, scale, offset or data changed
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
