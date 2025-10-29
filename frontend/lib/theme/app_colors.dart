import 'package:flutter/material.dart';

class AppColors {
  static const Color sidebarColor = Color(0xFF1E1E1E);
  static const Color appBarColor = Color(0xFF2D2D2D);
  static const Color appBarTitleColor = Color(0xFFF5F5F5);
  static const Color appBarIconColor = Color(0xFFF5F5F5);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color selectedIconColor = Colors.blueAccent;

  static final Gradient deviceUpGradient = RadialGradient(
    colors: [Color.fromRGBO(0, 128, 0, 1), Color.fromRGBO(0, 128, 0, 0.90)],
    stops: [0.0, 1.0]
  );

  static final Gradient deviceDownGradient = RadialGradient(
    colors: [Color.fromRGBO(255, 0, 0, 1), Color.fromRGBO(255, 86, 86, 0.894)],
    stops: [0.0, 1.0]
  );

  static final Gradient deviceUnknownGradient = RadialGradient(
    colors: [Color.fromRGBO(196, 148, 17, 1), Color.fromRGBO(207, 115, 8, 0.898)],
    stops: [0.0, 1.0]
  );

  // Default link paint
  static final Paint linkPaint = Paint()
    ..color = Color.fromRGBO(0, 52, 129, 1.0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  // Paint used for a link that's selected via click, or other ui direct interactions
  static final Paint selectedLinkPaint = Paint()
    ..color = Color.fromRGBO(3, 177, 90, 1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  // Paint used for a link that's being hovered on with a cursor, but not selected
  static final Paint hoveringLinkPaint = Paint()
    ..color = Color.fromRGBO(38, 145, 145, 1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  // Paint used as shadow underneath a hovered or selected link
  static final Paint linkShadowPaint = Paint()
    ..color = Color.fromRGBO(60, 106, 173, 1)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  // Paint used for the border around the canvas widget
  static final Paint canvasBorderPaint = Paint()
    ..color = Color.fromRGBO(107, 107, 107, 1)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

}
