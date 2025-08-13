import 'package:flutter/material.dart';

extension OffsetNDCConversion on Offset {

  Offset ndcToPixel(Size canvasSize) {
    final x = (dx + 1) / 2 * canvasSize.width;
    final y = (1 - dy) / 2 * canvasSize.height;
    return Offset(x, y);
  }

  Offset pixelToNDC(Size size) {
    final x = (dx / size.width) * 2 - 1;
    final y = -((dy / size.height) * 2 - 1); // y axis flipped
    return Offset(x, y);
  }

}

extension GlobalCoordinateConversion on Offset {
  Offset globalToPixel(Size canvasSize, double scale, Offset centerOffset) {
    // Step 1: Translate so that centerOffset is at the canvas center
    final Offset view = (this - centerOffset) * scale;

    // Step 2: Move origin from (0,0) to canvas center
    return view + Offset(canvasSize.width / 2, canvasSize.height / 2);
  }

  Offset pixelToGlobal(Size canvasSize, double scale, Offset centerOffset) {
    // Step 1: Move origin from center to (0,0)
    final Offset view = this - Offset(canvasSize.width / 2, canvasSize.height / 2);

    // Step 2: Undo scale
    final Offset unscaled = view / scale;

    // Step 3: Translate back to global coords
    return unscaled + centerOffset;
  }

}
