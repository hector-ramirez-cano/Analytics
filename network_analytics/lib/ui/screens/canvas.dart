import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/hover_interaction_service.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/theme/app_colors.dart';

import '../../providers/providers.dart';

extension OffsetNDCConversion on Offset {

  Offset ndcToPixel(Size canvasSize) {
    final x = (dx + 1) / 2 * canvasSize.width;
    final y = (1 - dy) / 2 * canvasSize.height;
    return Offset(x, y);
  }

  Offset pixelToNDC(Size size) {
    final x = (dx / size.width) * 2 - 1;
    final y = -((dy / size.height) * 2 - 1); // y axis flipped
    return Offset(x, y);
  }

}

// TODO: Refactor all this code into different files
class TopologyCanvas extends StatefulWidget {
  const TopologyCanvas({super.key});

  @override
  State<TopologyCanvas> createState() => _TopologyCanvasState();
}

class _TopologyCanvasState extends State<TopologyCanvas> {
  Size? canvasActualSize;
  HoverTarget? hovered;

  MouseRegion _makeCustomPaint(Topology topology, HoverInteractionService hoverInteractionService) {
    return MouseRegion (
      onHover: ((event) {
        if (canvasActualSize != null) {
          var curr = hoverInteractionService.getHoveredTarget(event.localPosition.pixelToNDC(canvasActualSize!));
          setState(() {
            hovered = curr;
          });
        
        }
      }),
      child: CustomPaint(
        size: Size.infinite,
        painter: TopologyCanvasPainter(
          topology: topology,
          hoverInteractionService: hoverInteractionService,
          onSizeChanged: ((size) {
            canvasActualSize = size;
          }),  
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Consumer(builder: 
      (context, ref, child) {
        final topologyAsync = ref.watch(topologyProvider);
        final hoverInteractionService = ref.watch(hoverInteractionServiceProvider);

        return topologyAsync.when(
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
          data: (topology) => _makeCustomPaint(topology, hoverInteractionService)
        );
      }
    );
    
  }
}

class TopologyCanvasPainter extends CustomPainter {
  Topology topology;
  HoverInteractionService hoverInteractionService;
  final void Function(Size) onSizeChanged;

  TopologyCanvasPainter({
    required this.topology,
    required this.hoverInteractionService,
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

      if (link.linkType == LinkType.wireless) {
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);

        final dashed = dashPath(path, dashArray: CircularIntervalList([10, 5]));
        canvas.drawPath(dashed, AppColors.linkPaint);
      } else {
        canvas.drawLine(start, end, AppColors.linkPaint);
      }
    }
  }

  void _registerHoverItems() {
    hoverInteractionService.clearTargets();
    
    topology.getDevices().forEach((device) => hoverInteractionService.registerTarget(device));
    topology.getLinks().forEach((link) => hoverInteractionService.registerTarget(link));
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
