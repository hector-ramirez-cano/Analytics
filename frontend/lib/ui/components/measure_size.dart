import 'package:flutter/material.dart';

class MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onChange;

  const MeasureSize({
    super.key,
    required this.child,
    required this.onChange,
  });

  @override
  _MeasureSizeState createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextRender = context.findRenderObject();
      if (contextRender is RenderBox) {
        final newSize = contextRender.size;
        if (oldSize == newSize) return;

        oldSize = newSize;
        widget.onChange(newSize);
      }
    });

    return widget.child;
  }
}
