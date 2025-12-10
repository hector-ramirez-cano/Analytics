import 'dart:ui';

import 'package:logger/web.dart';

class StyleDefinition {
  Map<String, List<Color>> swatch;

  StyleDefinition({
    required this.swatch
  });

  factory StyleDefinition.fromJson(Map<String, dynamic>? json) {
    final Map<String, List<Color>> swatch = {};

    if (json != null) {
      if (json["pie-colors"] != null) {
        final List<Color> colors = [];
        for (var colorStr in json["pie-colors"]) {
          int color = int.tryParse(colorStr, radix: 16) ?? 0;
          colors.add(Color(color));
        }
        swatch["pie-colors"] = colors;
      } else {
        swatch["pie-colors"] = [
          Color(0xFF858ae3),
          Color(0xFF7364d2),
          Color(0xFF613dc1),
          Color(0xFF5829a7),
          Color(0xFF4e148c),
          Color(0xFF2c0735),
        ];
      }

      if (json["text-colors"] != null) {
        final List<Color> colors = [];
        for (var colorStr in json["text-colors"]) {
          int color = int.tryParse(colorStr, radix: 16) ?? 0;
          colors.add(Color(color));
        }
        swatch["text-colors"] = colors;
      } else {
        swatch["text-colors"] = [
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
        ];
      }

      if (json["line-colors"] != null) {
        final List<Color> colors = [];
        for (var colorStr in json["line-colors"]) {
          int color = int.tryParse(colorStr, radix: 16) ?? 0;
          colors.add(Color(color));
        }
        swatch["line-colors"] = colors;
      } else {
        swatch["line-colors"] = [
          Color(0xFF4E79A7), // Soft Blue
          Color(0xFFF28E2B), // Soft Orange
          Color(0xFF59A14F), // Soft Green
          Color(0xFFE15759), // Soft Red
          Color(0xFFB07AA1), // Soft Purple
          Color(0xFF9C755F), // Soft Brown
          Color(0xFF76B7B2), // Aqua
          Color(0xFFBAB0AC), // Neutral Gray
        ];
      }

      if (swatch["pie-colors"]?.length != swatch["text-colors"]?.length) {
        Logger().w("pie-colors and text-colors don't have the same length. Smallest one will be used. Some colors might be missing");

        if ((swatch["pie-colors"]?.length ?? 0) > (swatch["text-colors"]?.length ?? 0)) {
          swatch["pie-colors"] = (swatch["pie-colors"] ?? []).sublist(0, swatch["text-colors"]?.length ?? 0);
        } else {
          swatch["text-colors"] = (swatch["text-colors"] ?? []).sublist(0, swatch["pie-colors"]?.length ?? 0);
        }
      }
    }


    return StyleDefinition(swatch: swatch);
  }

  List<Color> get lineColors => swatch["line-colors"] ?? [];
  List<Color> get pieColors => swatch["pie-colors"] ?? [];
  List<Color> get textColors => swatch["text-colors"] ?? [];
}