import 'package:flutter/material.dart';

class AppColors {
  static const Color sidebarColor = Color(0xFF1E1E1E);
  static const Color appBarColor = Color(0xFF2D2D2D);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color selectedIconColor = Colors.blueAccent;

  static final Gradient deviceGradient = RadialGradient(
    colors: [Color.fromRGBO(0, 128, 0, 1), Color.fromRGBO(0, 128, 0, 0.90)],
    stops: [0.0, 1.0]
  );

  static final Paint linkPaint = Paint()
    ..color = Color.fromRGBO(0, 52, 129, 1.0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
    

  static final Paint selectedLinkPaint = Paint()
    ..color = Color.fromRGBO(38, 145, 145, 1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;



  static final Paint canvasBorderPaint = Paint()
    ..color = Color.fromRGBO(107, 107, 107, 1)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  static final Paint linkShadowPaint = Paint()
    ..color = Color.fromRGBO(60, 106, 173, 1)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 32)
    ..style = PaintingStyle.stroke;
}
