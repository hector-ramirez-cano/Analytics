import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/extensions/offset.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/canvas_state_notifier.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';

typedef ItemChangedCallback = Function(bool);
typedef CanvasStateChangedCallback = Function(double? scale, Offset? center);
typedef CanvasSizeChangedCallback = Function(Size size);
typedef ScaleChangedCallback = Function(Offset cursorPixel, double scaleDelta, Size canvasSize);


abstract class HoverTarget {
  bool hitTest(Offset position);
  int getId();
}

class CanvasInteractionService {

  final List<HoverTarget> targets = [];
  final Duration delay = const Duration(milliseconds: 200);

  HoverTarget? hovered;
  HoverTarget? prevHovered;
  Timer? _hoverTimer;
  double _lastScale = 1.0;
  bool mouseMovingCanvas = false;
  final Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_canvas_interaction_logging", false));


  /// 
  /// Retrieves the first target over which the position (in global space) is colliding with. If no collision is detected, null will be returned
  /// [position] global-space position of the cursor, for which collision will be detected
  /// 
  HoverTarget? getHoveredTarget(Offset position) {
    for (final target in targets) {
      if (target.hitTest(position)) return target;
    }

    return null;
  }

  ///
  /// Makes the canvas scale and center offset move depending on the position at which the zoom happens.
  /// [focalPoint] point at which the scale and centerOffset will be moved toward
  /// [focalPointDelta] change in focalPoint since last call, to implement panning
  /// [scaleDelta] change in scale since last call
  /// [canvasSize] current size of the canvas in pixels
  /// [ref] WidgetRef to call to update the canvas scale and offset state
  /// 
  /// Example: If zooming-in to the canvas with the focalPoint on the top-left of the canvas, the center will be shifted towards the top-left
  void zoomAt(Offset focalPoint, Offset focalPointDelta, double scaleDelta, Size canvasSize, WidgetRef ref) {
    var state = ref.read(canvasStateNotifierService.notifier);

    final newScale = (state.scale * scaleDelta).clamp(0.1, 10.0);

    final globalBefore = focalPoint.pixelToGlobal(canvasSize, state.scale, state.centerOffset);

    state.setState(newScale, null);

    final globalAfter = focalPoint.pixelToGlobal(canvasSize, state.scale, state.centerOffset);

    final panGlobalDelta = Offset(
       focalPointDelta.dx / (canvasSize.width / 2 * state.scale),
       focalPointDelta.dy / (canvasSize.height / 2 * state.scale),
    );

    // Adjust offset so zoom pivots around cursor
    final offsetDelta = globalAfter - globalBefore;
    state.setState(null, state.centerOffset - offsetDelta - panGlobalDelta,);
  }

  ///
  /// Manually zooms the canvas by a given scaleDelta
  /// [scaleDelta] multiplicative zoom delta
  /// [ref] WidgetRef to ripple-notify state to other widgets via Riverpod
  void zoom(double scaleDelta, WidgetRef ref) {
    var state = ref.read(canvasStateNotifierService.notifier);
    final newScale = (state.scale * scaleDelta).clamp(0.1, 10.0);

    state.setState(newScale, null);
  }

  void resetCanvasState(WidgetRef ref) {
    ref.read(canvasStateNotifierService.notifier).reset();
  }

  void registerTarget(HoverTarget target) => targets.add(target);
  void clearTargets() => targets.clear();
  void onScaleStart() => _lastScale = 1.0;

  void onSelectTarget(bool forced, WidgetRef ref) {
    ref.read(itemSelectionProvider.notifier).setSelected(hovered?.getId(), forced);
  }

  void onCanvasStateChanged(double? scale, Offset? center, WidgetRef ref) {
    ref.read(canvasStateNotifierService.notifier).setState(scale, center);
  }
  
  void onEnter(PointerEvent event, ItemChangedCallback onChangeSelection) {
    callback() => onChangeSelection(false);

    if (hovered == null) {
      onExit(event);
    } else {
      _hoverTimer = Timer(delay, callback);
    }
  }

  void onExit(PointerEvent event) {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  void onHover(PointerEvent event, ItemChangedCallback onChangeSelection, ItemSelection? itemSelection, Size canvasSize, CanvasState state, Offset? positionPx) {
    if (positionPx != null) {
      var position = positionPx.pixelToGlobal(canvasSize, state.scale, state.centerOffset);
      var curr = getHoveredTarget(position);

      if (itemSelection != null && itemSelection.forced) {
        logger.d("Skipped interaction, selection is forced");
        return;
      }

      if (curr != prevHovered) {
        onExit(event);
        onEnter(event, onChangeSelection);

        logger.d("Currently Hovering over=$curr");
      
        prevHovered = hovered;
        hovered = curr;
      }

      if (curr == null) {
        onChangeSelection(false);
      }
    }
  }

  void onTapUp(TapUpDetails details, ItemChangedCallback onChangeSelection, ItemSelection? itemSelection, Size canvasSize, CanvasState state) {
    hovered = getHoveredTarget(details.localPosition.pixelToGlobal(canvasSize, state.scale, state.centerOffset));

    bool forced = hovered != null;
    onChangeSelection(forced);

    logger.d("On TapUp, hovered=$hovered, hovered=$hovered");
  }

  void onScaleUpdate(ScaleUpdateDetails details, Size canvasActualSize, WidgetRef ref) {
    if (details.pointerCount < 2) { return; }
      final scaleDelta = details.scale / _lastScale;
      _lastScale = details.scale;


    zoomAt(details.focalPoint, details.focalPointDelta, scaleDelta, canvasActualSize, ref);
    
    logger.d("OnScaleUp, scaleDelta=$scaleDelta");
  }

  void onPointerSignal(dynamic pointerSignal, Size canvasActualSize, WidgetRef ref) {
    if (pointerSignal is! PointerScrollEvent) { return; }

    final scaleDelta = pointerSignal.scrollDelta.dy > 0 ? 0.9 : 1.1;

    zoomAt(pointerSignal.localPosition, Offset.zero, scaleDelta, canvasActualSize, ref);

    logger.d("OnPointerSignal");
  }

  void onPointerDown(PointerEvent event) {
    var inputButtonConfig = AppConfig.getOrDefault("ui/move_canvas_with", defaultVal: "mouse1");

    const inputButtonMap = {
      "mouse1": kPrimaryMouseButton,
      "mouse2": kSecondaryMouseButton,
      "mouse3": kTertiaryButton,
    };

    var inputButton = inputButtonMap[inputButtonConfig] ?? kTertiaryButton;

    if (event.buttons == inputButton) {
      mouseMovingCanvas = true;
    }
    logger.d("OnPointerDown, button=${event.buttons}");
  }

  void onPointerUp(PointerEvent event) {
    mouseMovingCanvas = false;

    logger.d("OnPointerUp, button=${event.buttons}");
  }

  void onPointerMove(PointerEvent event, Size canvasActualSize, WidgetRef ref) {
    if (!mouseMovingCanvas) {
      return;
    }

    var delta = event.localDelta;
    var naturalScrolling = AppConfig.getOrDefault("ui/natural_scrolling", defaultVal: false);
    if (naturalScrolling) {
      delta = -delta;
    }

    zoomAt(event.localPosition, delta, 1.0, canvasActualSize, ref);

    logger.d("OnPointerMove, position=${event.localPosition}, delta=$delta, naturalScrolling=$naturalScrolling");
  }

  MouseCursor setCursor() {
    if (mouseMovingCanvas) {
      return SystemMouseCursors.move;
    }

    return SystemMouseCursors.basic;
  }
} 