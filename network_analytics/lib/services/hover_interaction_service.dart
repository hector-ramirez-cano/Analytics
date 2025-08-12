import 'dart:ui';

// ignore: unused_import
import 'package:logger/web.dart';

abstract class HoverTarget {
  bool hitTest(Offset positionNDC);
  int getId();
}

class CanvasInteractionService {
  final List<HoverTarget> targets = [];


  HoverTarget? getHoveredTarget(Offset positionNDC) {
    for (final target in targets) {
      if (target.hitTest(positionNDC)) return target;
    }

    return null;
  }

  void registerTarget(HoverTarget target) => targets.add(target);
  void clearTargets() => targets.clear();
  
}

