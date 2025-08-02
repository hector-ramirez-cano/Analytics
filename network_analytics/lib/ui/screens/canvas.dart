import 'package:flutter/material.dart';

class TopologyCanvas extends StatefulWidget {
  const TopologyCanvas({super.key});

  @override
  State<TopologyCanvas> createState() => _TopologyCanvasState();
}

class _TopologyCanvasState extends State<TopologyCanvas> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TopologyCanvasPainter(),
      size: const Size(300, 300), // or Size.infinite if flexible
    );
  }
}

class TopologyCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint circlePaint = Paint()
      ..color = const Color.fromARGB(255, 20, 20, 20)
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.grey.shade200,
    );

    // Draw circle in center
    canvas.drawCircle(
      size.center(Offset.zero),
      50,
      circlePaint,
    );

    // Draw diagonal line
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      linePaint,
    );

    // Draw border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
