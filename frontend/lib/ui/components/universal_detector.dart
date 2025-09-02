import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class UniversalDetector extends StatelessWidget {
  final Widget child;
  final GestureTapUpCallback? onTapUp;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleStartCallback? onScaleStart;
  final PointerHoverEventListener? onHover;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final PointerSignalEventListener? onPointerSignal;
  final PointerDownEventListener? onPointerDown;
  final PointerUpEventListener? onPointerUp;
  final PointerMoveEventListener? onPointerMove;
  final HitTestBehavior behavior;

  final MouseCursor Function() setCursor;

  const UniversalDetector({
    super.key,
    this.onTapUp,
    this.onScaleUpdate,
    this.onHover,
    this.onEnter,
    this.onExit,
    this.onPointerSignal,
    this.onScaleStart,
    this.onPointerDown,
    this.onPointerUp,
    this.onPointerMove,
    this.behavior = HitTestBehavior.deferToChild,
    required this.setCursor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: behavior,
      onPointerSignal: onPointerSignal,
      onPointerDown: onPointerDown,
      onPointerUp: onPointerUp,
      onPointerMove: onPointerMove,
      child: GestureDetector(
        onTapUp: onTapUp,
        onScaleUpdate: onScaleUpdate,
        onScaleStart: onScaleStart,
        child: MouseRegion(
          cursor: setCursor(),
          onHover: onHover,
          onEnter: onEnter,
          onExit: onExit,
          child: child,
        ),
      ),
    );
  }
}
