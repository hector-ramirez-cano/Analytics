import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology_view/topology_view.dart';
import 'package:network_analytics/services/canvas/canvas_interaction_service.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/canvas/canvas_tabs_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';
import 'package:network_analytics/services/topology/topology_provider.dart';
import 'package:network_analytics/services/topology/topology_view_template_provider.dart';
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
    TopologyView topologyView,
    CanvasInteractionService canvasInteractionService,
    CanvasTabs canvasTabs,
    ItemSelection? itemSelection,
    BuildContext context,
    WidgetRef ref,
  ) {
    var onCanvasStateChanged = ((scale, center) => canvasInteractionService.onCanvasStateChanged(scale, center, ref));
    var onChangeSelection    = ((forced)  => canvasInteractionService.onSelectTarget(forced, ref));
    var onSizeChanged        = ((size)    => canvasActualSize = size);
    var onScaleStart         = ((_)       => canvasInteractionService.onScaleStart());
    var onScaleUpdate        = ((details) => canvasInteractionService.onScaleUpdate(details, context, canvasActualSize, ref));
    var onTapUp              = ((details) => canvasInteractionService.onTapUp(details, onChangeSelection, itemSelection, canvasActualSize, canvasTabs));
    var onHover              = ((event)   => canvasInteractionService.onHover(event, onChangeSelection, itemSelection, canvasActualSize, canvasTabs, event.localPosition));
    var onPointerSignal      = ((signal)  => canvasInteractionService.onPointerSignal(signal, canvasActualSize, ref));
    var onPointerDown        = ((event)   => canvasInteractionService.onPointerDown(event));
    var onPointerUp          = ((event)   => canvasInteractionService.onPointerUp(event));
    var onPointerMove        = ((event)   => canvasInteractionService.onPointerMove(event, canvasActualSize, ref));
    var setCursor            = (()        => canvasInteractionService.setCursor());

    return UniversalDetector(
      onTapUp        : onTapUp,
      onScaleStart   : onScaleStart,
      onScaleUpdate  : onScaleUpdate,
      onHover        : onHover,
      onPointerSignal: onPointerSignal,
      onPointerDown  : onPointerDown,
      onPointerUp    : onPointerUp,
      onPointerMove  : onPointerMove,
      setCursor      : setCursor,
      
      child: CustomPaint(
        size: Size.infinite,
        painter: TopologyCanvasPainter(
          topologyView: topologyView,
          itemSelection: itemSelection,
          canvasInteractionService: canvasInteractionService,
          canvasTabs: canvasTabs,
          onCanvasStateChanged: onCanvasStateChanged,
          onSizeChanged: onSizeChanged
        ),
      ),
    );
  }

  Widget _makeFloatingButtons() {
    Widget makeFab(String heroTag, Icon icon, VoidCallback onPressed) {
      return FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        onPressed: onPressed,
        backgroundColor: Color.fromRGBO(237, 244, 250, 1),
        foregroundColor: Color.fromRGBO(49, 49, 49, 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // fixed shape
        ),
        child: icon,
      );
    }

    return Consumer(builder: 
      (context, ref, child) {
        final canvasInteractionService = ref.watch(canvasInteractionServiceProvider);
        final canvasState = ref.watch(canvasTabsProvider).selectedState!;

        final isCenterButtonVisible = canvasState.isModified;

        return Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              makeFab("zoom_in", Icon(Icons.zoom_in), () => canvasInteractionService.zoom(1.1, ref)),
              SizedBox(height: 8),
              makeFab("zoom_out", Icon(Icons.zoom_out), () => canvasInteractionService.zoom(0.9, ref)),
              SizedBox(height: 8),
              ?isCenterButtonVisible ? 
                makeFab("center", Icon(Icons.center_focus_weak), () => canvasInteractionService.resetCanvasState(ref)) 
                : null
            ], 
          ),
        );
      }
    );
  }

  Widget _makeEmptyTabSelection() {
    return SizedBox.expand(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // keeps the column as small as possible
          children: [
            Spacer(),
            Icon(Icons.category_outlined, size: 128, color: Colors.blueGrey,),
            SizedBox(height: 12), // spacing between icon and text
            Text("Selecciona una vista"),
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _makeGeoView() {
    return SizedBox.shrink();
  }

  // TODO: REFACTOR
  @override
  Widget build(BuildContext context) {

    return Consumer(builder:
      (context, ref, child) {
        final canvasInteractionService = ref.watch(canvasInteractionServiceProvider);
        final canvasItemSelection = ref.watch(itemSelectionProvider);
        final topologyTemplates = ref.watch(topologyViewTemplatesProvider);
        final canvasTabs = ref.watch(canvasTabsProvider);

        onRetry () async => ref.refresh(topologyServiceProvider.future);

        return topologyTemplates.when(
          loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
          error: (error, stackTrace) => RetryIndicator(onRetry: onRetry, error: error.toString(), isLoading: topologyTemplates.isLoading,),
          data: (topology) {
            final selectedTab = canvasTabs.selectedTab;
            final selectedState = canvasTabs.selectedState;
            if (selectedTab == null || selectedState == null) { 
              return _makeEmptyTabSelection(); 
            }

            if (selectedTab.template.isPhysicalView) {
              return _makeGeoView();
            }

            return Stack (children:[
              _makeCustomPaint(
                selectedTab,
                canvasInteractionService,
                canvasTabs,
                canvasItemSelection,
                context,
                ref
              ),
              _makeFloatingButtons()
            ]);
          }
        );
      }
    );
  }
}
