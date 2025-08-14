import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/offset.dart';

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

  void setState(double? scale, Offset? centerOffset) {
    bool changed = state.scale != scale || state.centerOffset != centerOffset;

    if (changed) {
      Logger().w("[PERFORMANCE]Changed canvas state!, scale=$scale, centerOffset=$centerOffset");
      state = state.copyWith(scale: scale, centerOffset: centerOffset);
    }
  }

  void pan(Offset delta) {
    state = state.copyWith(
      centerOffset: state.centerOffset + delta,
    );
  }

  void zoomAt(Offset cursorPixelPos, double zoomDelta, Size canvasSize) {
    final newScale = (state.scale * zoomDelta).clamp(0.1, 10.0);

    // Convert cursor position to global coords before zoom
    final globalBefore = cursorPixelPos.pixelToGlobal(canvasSize, state.scale, state.centerOffset);

    // Update scale
    state = state.copyWith(scale: newScale);

    // Convert same cursor pixel position to global after zoom
    final globalAfter = cursorPixelPos.pixelToGlobal(canvasSize, state.scale, state.centerOffset);

    // Adjust offset so zoom pivots around cursor
    final offsetDelta = globalAfter - globalBefore;
    state = state.copyWith(centerOffset: state.centerOffset - offsetDelta);
  }
}