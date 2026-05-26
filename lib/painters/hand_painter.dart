import 'package:flutter/material.dart';

class HandPainter extends CustomPainter {
  final List<Offset> points;
  final bool isFrontCamera;

  HandPainter({required this.points, required this.isFrontCamera});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintDot = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    for (var point in points) {
      double x = point.dx * size.width;
      double y = point.dy * size.height;

      if (isFrontCamera) {
        x = size.width - x; // Standard front camera horizontal mirroring
      }

      canvas.drawCircle(Offset(x, y), 6.0, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant HandPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
