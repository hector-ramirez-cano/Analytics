import 'package:flutter/material.dart';
import 'dart:async';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/offset.dart';
import 'package:network_analytics/services/item_selection_notifier.dart';

typedef ItemChangedCallback = Function(bool);


abstract class HoverTarget {
  bool hitTest(Offset positionNDC);
  int getId();
}

class CanvasInteractionService {
  final List<HoverTarget> targets = [];
  final Duration delay = const Duration(milliseconds: 200);

  HoverTarget? hovered;
  HoverTarget? prevHovered;
  Timer? _hoverTimer;

  HoverTarget? getHoveredTarget(Offset positionNDC) {
    for (final target in targets) {
      if (target.hitTest(positionNDC)) return target;
    }

    return null;
  }

  void registerTarget(HoverTarget target) => targets.add(target);
  void clearTargets() => targets.clear();
  

  void onEnter(PointerEvent event, ItemChangedCallback onChangeSelection) {
    callback() => {
      onChangeSelection(false)
    };

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

  void onHover(PointerEvent event, ItemChangedCallback onChangeSelection, ItemSelection? itemSelection, Offset? positionNDC) {
    if (positionNDC != null) {
      var curr = getHoveredTarget(positionNDC);

      if (itemSelection != null && itemSelection.forced) {
        // Logger().d("Skipped interaction, selection is forced");
        return;
      }

      if (curr != prevHovered) {
        onExit(event);
        onEnter(event, onChangeSelection);

        // Logger().d("Currently Hovering over=$curr");
      
        prevHovered = hovered;
        hovered = curr;
        
      }

      if (curr == null) {
        onChangeSelection(false);
      }
    }
  }

  void onTapUp(TapUpDetails details, ItemChangedCallback onChangeSelection,  ItemSelection? itemSelection, Size canvasActualSize) {
    hovered = getHoveredTarget(details.localPosition.pixelToNDC(canvasActualSize));
    // Logger().d("On TapUp, hovered=$hovered");

    bool forced = hovered != null;

    onChangeSelection(forced);
  }
}

