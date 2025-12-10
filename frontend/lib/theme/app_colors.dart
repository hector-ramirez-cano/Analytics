import 'package:flutter/material.dart';

class AppColors {
  static const Color sidebarColor = Color(0xFF1E1E1E);
  static const Color appBarColor = Color(0xFF2D2D2D);
  static const Color appBarTitleColor = Color(0xFFF5F5F5);
  static const Color appBarIconColor = Color(0xFFF5F5F5);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color selectedIconColor = Colors.blueAccent;

  static const Color deviceUpColor = Color.fromRGBO(0, 128, 0, 1);
  static const Color deviceDownColor = Color.fromRGBO(255, 0, 0, 1);
  static const Color deviceUpPartialColor = Color.fromRGBO(196, 148, 17, 1);
  static const Color deviceUnknownColor = Color.fromRGBO(128, 128, 128, 1);

  static const Color notificationBadgeIconColor = Colors.redAccent;
  static const Color notificationUnknownStateBadgeColor = Colors.blueGrey;
  static const Color notificationIconColor = Colors.white;

  static const Color alertRtColorEntry = Colors.green;
  static const Color alertRtColorExit = Color.fromARGB(0, 76, 175, 79);
  static const Color overlayBackgroundColor = Colors.white;
  static const Color overlayRtOverlayShadowColor = Colors.black26;
  static const Color overlayRtOverlaySubtitleColor = Colors.black54;
  static const Color overlayRtOverlayDetailsColor = Colors.black87;

  static const Color alertRuleEditBadgeFontColor = Colors.black87;
  static const Color alertRuleEditOpSelectorFontColor = Colors.white;
  static const Color alertRuleEditOpSelectorSelectedBackgroundColor = Color.fromRGBO(41, 99, 138, 1);
  static const Color alertRuleEditOpSelectorBackgroundColor = Colors.white;

  static final Gradient deviceUpGradient = RadialGradient(
    colors: [deviceUpColor, deviceUpColor.withAlpha(200)],
    stops: [0.0, 1.0]
  );

  static final Gradient deviceDownGradient = RadialGradient(
    colors: [deviceDownColor, Color.fromRGBO(255, 86, 86, 0.894)],
    stops: [0.0, 1.0]
  );

  static final Gradient devicePartialUpGradient = RadialGradient(
    colors: [deviceUpPartialColor, Color.fromRGBO(160, 119, 65, 0.89)],
    stops: [0.0, 1.0]
  );

  static final Gradient deviceUnknownGradient = RadialGradient(
    colors: [deviceUnknownColor, Color.fromRGBO(94, 94, 94, 0.894)],
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
