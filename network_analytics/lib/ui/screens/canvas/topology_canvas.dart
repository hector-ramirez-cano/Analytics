import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/canvas_interaction_service.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/canvas_state_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
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

  UniversalDetector _makeCustomPaint(
    Topology topology,
    CanvasInteractionService canvasInteractionService,
    CanvasState canvasState,
    ItemSelection? itemSelection,
    WidgetRef ref,
  ) {
    var onChangeSelection    = ((forced)  => canvasInteractionService.onSelectTarget(forced, ref));
    var onSizeChanged        = ((size)    => canvasActualSize = size);
    var onScaleStart         = ((_)       => canvasInteractionService.onScaleStart());
    var onScaleUpdate        = ((details) => canvasInteractionService.onScaleUpdate(details, canvasActualSize, ref));
    var onPointerSignal      = ((signal)  => canvasInteractionService.onPointerSignal(signal, canvasActualSize, ref));
    var onHover              = ((event)   => canvasInteractionService.onHover(event, onChangeSelection, itemSelection, canvasActualSize, canvasState, event.localPosition));
    var onTapUp              = ((details) => canvasInteractionService.onTapUp(details, onChangeSelection, itemSelection, canvasActualSize, canvasState));
    var onCanvasStateChanged = ((scale, center) => canvasInteractionService.onCanvasStateChanged(scale, center, ref));

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

        onRetry () async => {
          ref.refresh(topologyProvider.future)
        };

        return topologyAsync.when(
          loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
          error: (error, stackTrace) => RetryIndicator(onRetry: onRetry, error: error.toString(), isLoading: topologyAsync.isLoading,),
          data: (topology) => 
            _makeCustomPaint(
              topology,
              canvasInteractionService,
              canvasState,
              canvasItemSelection,
              ref
            )
        );
      }
    );
  }

}
