import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'canvas_state_notifier.g.dart'; // must match file name

// Immutable state class
class CanvasState {
  final double scale;
  final Offset centerOffset;
  final bool isModified;

  CanvasState({
    required this.scale,
    required this.centerOffset,
    this.isModified = false,
  });

  CanvasState copyWith({
    double? scale,
    Offset? centerOffset,
    bool? isModified,
  }) {
    return CanvasState(
      scale: scale ?? this.scale,
      centerOffset: centerOffset ?? this.centerOffset,
      isModified: isModified ?? this.isModified,
    );
  }
}

// Riverpod 3 Notifier
@riverpod
class CanvasStateNotifier extends _$CanvasStateNotifier {
  @override
  CanvasState build() => CanvasState(scale: 1.0, centerOffset: Offset.zero);

  double get scale => state.scale;
  Offset get centerOffset => state.centerOffset;
  bool get isModified => state.isModified;

  void setState(double? scale, Offset? centerOffset) {
    final changed = (scale != null && scale != state.scale) ||
        (centerOffset != null && centerOffset != state.centerOffset);

    if (changed) {
      state = state.copyWith(
        scale: scale ?? state.scale,
        centerOffset: centerOffset ?? state.centerOffset,
        isModified: true,
      );
    }
  }

  void reset() {
    state = state.copyWith(
      scale: 1.0,
      centerOffset: Offset.zero,
      isModified: false,
    );
  }

  void pan(Offset delta) {
    state = state.copyWith(
      centerOffset: state.centerOffset + delta,
      isModified: true,
    );
  }
}
