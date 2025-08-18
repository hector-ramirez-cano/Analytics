import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';

class CanvasState {
  final double scale;
  final Offset centerOffset;

  CanvasState({
    required this.scale,
    required this.centerOffset
  });

  CanvasState copyWith({
    double? scale,
    Offset? centerOffset,
    Size? canvasSize,
  }) {
    return CanvasState(
      scale: scale ?? this.scale,
      centerOffset: centerOffset ?? this.centerOffset
    );
  }
}

class CanvasStateNotifierService extends StateNotifier<CanvasState> {
  CanvasStateNotifierService() : super(CanvasState(scale: 1.0, centerOffset: Offset.zero));

  double get scale => state.scale;
  Offset get centerOffset => state.centerOffset;

  void setState(double? scale, Offset? centerOffset) {
    bool changed = state.scale != scale || state.centerOffset != centerOffset;

    if (changed) {
      state = state.copyWith(scale: scale, centerOffset: centerOffset);
    }
  }

  void pan(Offset delta) {
    state = state.copyWith(
      centerOffset: state.centerOffset + delta,
    );
  }

}