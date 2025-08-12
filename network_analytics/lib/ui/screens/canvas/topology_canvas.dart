import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/hover_interaction_service.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/canvas/topology_canvas_painter.dart';

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

class TopologyCanvas extends StatefulWidget {
  const TopologyCanvas({
    super.key
  });

  @override
  State<TopologyCanvas> createState() => _TopologyCanvasState();
}

class _TopologyCanvasState extends State<TopologyCanvas> {  
  Size? canvasActualSize;


  MouseRegion _makeCustomPaint(
    Topology topology,
    CanvasInteractionService canvasInteractionService,
    int? itemSelection,
    VoidCallback onChangeSelection
  ) {

    return MouseRegion (
      onHover: ((event) => canvasInteractionService.onHover(event, onChangeSelection, event.localPosition.pixelToNDC(canvasActualSize!))),
      child: CustomPaint(
        size: Size.infinite,
        painter: TopologyCanvasPainter(
          topology: topology,
          itemSelection: itemSelection,
          canvasInteractionService: canvasInteractionService,
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
        final canvasInteractionService = ref.watch(canvasInteractionServiceProvider);
        final canvasItemSelection = ref.watch(itemSelectionProvider);

        onChangeSelection() => {
          if(mounted) {
            ref.read(itemSelectionProvider.notifier).setSelected(canvasInteractionService.hovered?.getId()),
          }};

        return topologyAsync.when(
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
          data: (topology) => _makeCustomPaint(topology, canvasInteractionService, canvasItemSelection, onChangeSelection)
        );
      }
    );
  }

}
