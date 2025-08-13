import 'package:flutter/material.dart';

extension OffsetNDCConversion on Offset {

  // Offset ndcToPixel(Size canvasSize) {
  //   final x = (dx + 1) / 2 * canvasSize.width;
  //   final y = (1 - dy) / 2 * canvasSize.height;
  //   return Offset(x, y);
  // }
// 
  // Offset pixelToNDC(Size size) {
  //   final x = (dx / size.width) * 2 - 1;
  //   final y = -((dy / size.height) * 2 - 1); // y axis flipped
  //   return Offset(x, y);
  // }

}

extension GlobalCoordinateConversion on Offset {
  Offset globalToPixel(Size canvasSize, double scale, Offset centerOffset) {
    final halfW = canvasSize.width / 2;
    final halfH = canvasSize.height / 2;

    // Translate from global space to pixel space
    // Global (0,0) → pixel center
    // Global (1,1) → bottom right corner when scale=1
    final pixelX = halfW + (dx + centerOffset.dx) * halfW * scale;
    final pixelY = halfH - (dy + centerOffset.dy) * halfH * scale; // Flip Y so +Y is up

    return Offset(pixelX, pixelY);
  }


  Offset pixelToGlobal(Size canvasSize, double scale, Offset centerOffset) {
    final halfW = canvasSize.width / 2;
    final halfH = canvasSize.height / 2;

    final globalX =  ((dx - halfW) / (halfW * scale)) - centerOffset.dx;
    final globalY = -((dy - halfH) / (halfH * scale)) - centerOffset.dy;

    return Offset(globalX, globalY);
  }

}
