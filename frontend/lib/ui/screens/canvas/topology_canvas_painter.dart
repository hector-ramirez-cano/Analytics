import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:aegis/models/topology_view/topology_view.dart';
import 'package:aegis/services/canvas/canvas_interaction_service.dart';
import 'package:aegis/services/canvas/canvas_tabs_notifier.dart';
import 'package:aegis/services/item_selection_notifier.dart';

import 'package:aegis/theme/app_colors.dart';
import 'package:aegis/extensions/offset.dart';

class TopologyCanvasPainter extends CustomPainter {
  TopologyView topologyView;
  CanvasInteractionService canvasInteractionService;
  CanvasTabs canvasTabs;

  final ItemSelection? itemSelection;
  final CanvasStateChangedCallback onCanvasStateChanged;
  final CanvasSizeChangedCallback onSizeChanged;

  TopologyCanvasPainter({
    required this.topologyView,
    required this.canvasInteractionService,
    required this.canvasTabs,
    required this.itemSelection,
    required this.onCanvasStateChanged,
    required this.onSizeChanged,
  });

  void _paintDevices(Canvas canvas, Size size) {
    final canvasState = canvasTabs.selectedState;
    if (canvasState == null) return;

    double scale = canvasState.scale;
    Offset centerOffset = canvasState.centerOffset;

    for (var device in topologyView.devices) {
      final memberPosition = canvasTabs.getPositionInState(device.id);
      final position = memberPosition.globalToPixel(size, scale, centerOffset);
      final devicePaint = device.getPaint(position, size);
      double radius = 6;

      if (canvasInteractionService.hovered?.getId() == device.getId()) {
        radius = 10;
      }

      canvas.drawCircle(position, radius, devicePaint);
    }
  }

  void _paintLinks(Canvas canvas, Size size) {
    final canvasState = canvasTabs.selectedState;
    if (canvasState == null) return;

    double scale = canvasState.scale;
    Offset centerOffset = canvasState.centerOffset;

    for (var link in topologyView.links) {

      final Paint linkPaint = link.getPaint(itemSelection);
      final sideAPosition = canvasTabs.getPositionInState(link.sideA.id);
      final sideBPosition = canvasTabs.getPositionInState(link.sideB.id);
      final path = link.getPath(size, scale, centerOffset, sideAPosition, sideBPosition);

      if (itemSelection?.selected == link.getId()) {
        canvas.drawPath(path, AppColors.linkShadowPaint);
      }

      canvas.drawPath(path, linkPaint);

    }
  }

  void _registerHoverItems() {
    canvasInteractionService.clearTargets();

    for (var device in topologyView.devices) {
      canvasInteractionService.registerTarget(device);
    }
    for (var link in topologyView.links) {
      canvasInteractionService.registerTarget(link);
    }
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
