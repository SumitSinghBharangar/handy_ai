import 'package:flutter/material.dart';

class HandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    // TEMP DEMO POINTS

    final points = [
      const Offset(200, 300),
      const Offset(250, 250),
      const Offset(300, 200),
      const Offset(350, 170),
      const Offset(400, 150),
    ];

    // DRAW LINES

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // DRAW POINTS

    for (final point in points) {
      canvas.drawCircle(point, 10, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
