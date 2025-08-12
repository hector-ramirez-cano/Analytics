import 'package:flutter/material.dart';
import 'dart:async';

// ignore: unused_import
import 'package:logger/web.dart';

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
  

  void onEnter(PointerEvent event, VoidCallback onChangeSelection){
    if (hovered == null) {
      onExit(event);
    } else {
      _hoverTimer = Timer(delay, onChangeSelection);
    }
  }

  void onExit(PointerEvent event) {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  void onHover(PointerEvent event, VoidCallback onChangeSelection, Offset? positionPX) {
    if (positionPX != null) {
      var curr = getHoveredTarget(positionPX);

      if (curr != prevHovered) {
        onExit(event);
        onEnter(event, onChangeSelection);

        // Logger().d("Currently Hovering over=$curr");
      
        prevHovered = hovered;
        hovered = curr;
        
      }

      if (curr == null) {
        onChangeSelection();
      }
    }
  }
}

