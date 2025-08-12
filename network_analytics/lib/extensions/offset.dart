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
