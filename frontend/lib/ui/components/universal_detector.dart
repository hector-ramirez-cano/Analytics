import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Wraps a widget in a detector that can hold GestureDetection, Listener and MouseRegion for input detection.
/// Useful to handle input for Android/PC at the same time, "Universal" detector.
class UniversalDetector extends StatelessWidget {
  final Widget child;
  final GestureTapUpCallback? onTapUp;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
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

  final MouseCursor Function()? setCursor;

  const UniversalDetector({
    super.key,
    this.onTapUp,
    this.onPanUpdate,
    this.onPanEnd,
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
    this.setCursor,
    required this.child,
  });

  Widget _makeGestureDetector({required Widget child}) {
    // if there are not functions defined, return child as is
    if (onTapUp == null && onScaleUpdate == null && onScaleStart == null) { return child; }

    return GestureDetector(
        onTapUp: onTapUp,
        onScaleUpdate: onScaleUpdate,
        onScaleStart: onScaleStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: child,
      );
  }

  Widget _makeMouseRegion({required Widget child}) {
    if (onHover == null && onEnter == null && onExit == null && setCursor == null) { return child; }

    return MouseRegion(
          cursor: setCursor != null ? setCursor!() : SystemMouseCursors.basic,
          onHover: onHover,
          onEnter: onEnter,
          onExit: onExit,
          child: child,
        );
  }

  Widget _makeListener({required Widget child}) {
    if (onPointerSignal == null && onPointerDown == null && onPointerUp == null && onPointerMove == null) { return child; }

    return Listener(
      behavior: behavior,
      onPointerSignal: onPointerSignal,
      onPointerDown: onPointerDown,
      onPointerUp: onPointerUp,
      onPointerMove: onPointerMove,
      child: child
    );
  }

  @override
  Widget build(BuildContext context) {
    return _makeListener(
      child: _makeGestureDetector(
        child: _makeMouseRegion(
          child: child
        )
      )
    );
  }
}
