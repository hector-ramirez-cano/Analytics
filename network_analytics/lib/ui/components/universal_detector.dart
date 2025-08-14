import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class UniversalDetector extends StatelessWidget {
  final Widget child;
  final void Function(TapUpDetails)? onTapUp;
  final void Function(ScaleUpdateDetails)? onScaleUpdate;
  final void Function(PointerHoverEvent)? onHover;
  final void Function(PointerSignalEvent)? onPointerSignal;
  final void Function(ScaleStartDetails)? onScaleStart;

  const UniversalDetector({
    super.key,
    required this.child,
    this.onTapUp,
    this.onScaleUpdate,
    this.onHover,
    this.onPointerSignal,
    this.onScaleStart,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: onPointerSignal,
      child: GestureDetector(
        onTapUp: onTapUp,
        onScaleUpdate: onScaleUpdate,
        onScaleStart: onScaleStart,
        child: MouseRegion(
          onHover: onHover,
          child: child,
        ),
      ),
    );
  }
}
