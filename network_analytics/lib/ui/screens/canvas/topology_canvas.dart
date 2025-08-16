import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/canvas_state_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';
import 'package:network_analytics/ui/screens/canvas/topology_canvas_painter.dart';

class TopologyCanvas extends StatefulWidget {
  const TopologyCanvas({
    super.key
  });

  @override
  State<TopologyCanvas> createState() => _TopologyCanvasState();
}

class _TopologyCanvasState extends State<TopologyCanvas> {
  late Size canvasActualSize;
  double _lastScale = 1.0;

  UniversalDetector _makeCustomPaint(
    Topology topology,
    CanvasInteractionService canvasInteractionService,
    CanvasState canvasState,
    ItemSelection? itemSelection,
    ItemChangedCallback onChangeSelection,
    CanvasStateChangedCallback onCanvasStateChanged,
    ScaleChangedCallback onScaleChanged,
  ) {

    var onHover         = ((event)   => canvasInteractionService.onHover(event, onChangeSelection, itemSelection, canvasActualSize, canvasState, event.localPosition));
    var onTapUp         = ((details) => canvasInteractionService.onTapUp(details, onChangeSelection, itemSelection, canvasActualSize, canvasState));
    var onSizeChanged   = ((size)    => canvasActualSize = size);
    var onScaleStart    = ((_)       => _lastScale = 1.0);

    var onScaleUpdate   = ((details) {
      if (details.pointerCount < 2) { return; }
      final zoomDelta = details.scale / _lastScale;
      _lastScale = details.scale;

      canvasInteractionService.onScaleUpdate(details.focalPoint, zoomDelta, canvasActualSize, onScaleChanged);
    });

    var onPointerSignal = ((pointerSignal) {
      if (pointerSignal is! PointerScrollEvent) { return; }

        final zoomFactor = pointerSignal.scrollDelta.dy > 0 ? 0.9 : 1.1;
        canvasInteractionService.onScaleUpdate(
          pointerSignal.localPosition,
          zoomFactor,
          canvasActualSize,
          onScaleChanged
        );
    });

    return UniversalDetector(
      onTapUp        : onTapUp,
      onScaleStart   : onScaleStart,
      onScaleUpdate  : onScaleUpdate,
      onPointerSignal: onPointerSignal,
      onHover        : onHover,
      
      child: CustomPaint(
        size: Size.infinite,
        painter: TopologyCanvasPainter(
          topology: topology,
          itemSelection: itemSelection,
          canvasInteractionService: canvasInteractionService,
          canvasState: canvasState,
          onCanvasStateChanged: onCanvasStateChanged,
          onSizeChanged: onSizeChanged
        ),
      ),
    );

  
  }

  @override
  Widget build(BuildContext context) {

    return Consumer(builder:
      (context, ref, child) {
        final canvasInteractionService = ref.watch(canvasInteractionServiceProvider);
        final canvasItemSelection = ref.watch(itemSelectionProvider);
        final topologyAsync = ref.watch(topologyProvider);
        final canvasState = ref.watch(canvasStateNotifierService);

        onChangeSelection(bool forced) => {
          if(mounted) {
            ref.read(itemSelectionProvider.notifier).setSelected(canvasInteractionService.hovered?.getId(), forced),
          }};

        onCanvasStateChanged({Size? size, double? scale, Offset? center}) => {
          ref.read(canvasStateNotifierService.notifier).setState(scale, center)
        };

        onScaleChanged(Offset cursorPixel, double zoomDelta, Size canvasSize) => {
          ref.read(canvasStateNotifierService.notifier).zoomAt(cursorPixel, zoomDelta, canvasSize)
        };

        return topologyAsync.when(
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'), // TODO: Graceful handling
          data: (topology) => 
            _makeCustomPaint(
              topology,
              canvasInteractionService,
              canvasState,
              canvasItemSelection,
              onChangeSelection,
              onCanvasStateChanged,
              onScaleChanged
            )
        );
      }
    );
  }

}
