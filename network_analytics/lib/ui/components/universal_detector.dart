import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class UniversalDetector extends StatelessWidget {
  final Widget child;
  final void Function(TapUpDetails)? onTapUp;
  final void Function(ScaleUpdateDetails)? onScaleUpdate;
  final void Function(PointerHoverEvent)? onHover;
  final void Function(ScaleStartDetails)? onScaleStart;
  final void Function(PointerSignalEvent)? onPointerSignal;
  final void Function(PointerEvent)? onPointerDown;
  final void Function(PointerEvent)? onPointerUp;
  final void Function(PointerEvent)? onPointerMove;

  final MouseCursor Function() setCursor;

  const UniversalDetector({
    super.key,
    required this.child,
    this.onTapUp,
    this.onScaleUpdate,
    this.onHover,
    this.onPointerSignal,
    this.onScaleStart,
    this.onPointerDown,
    this.onPointerUp,
    this.onPointerMove,
    required this.setCursor,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
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
          child: child,
        ),
      ),
    );
  }
}
