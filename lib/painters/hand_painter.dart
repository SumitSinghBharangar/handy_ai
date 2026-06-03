import 'package:flutter/material.dart';

class HandPainter extends CustomPainter {
  final List<List<Offset>> handsPoints;

  HandPainter({required this.handsPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (handsPoints.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color.fromARGB(255, 246, 248, 247)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color.fromARGB(255, 48, 120, 243)
      ..style = PaintingStyle.fill;

    final List<List<int>> fingerConnections = [
      [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
      [0, 5], [5, 6], [6, 7], [7, 8], // Index Finger
      [9, 10], [10, 11], [11, 12], // Middle Finger
      [13, 14], [14, 15], [15, 16], // Ring Finger
      [0, 17], [17, 18], [18, 19], [19, 20], // Pinky Finger
      [5, 9], [9, 13], [13, 17], // Palm Base
    ];

    // Helper function to translate and correct the coordinate alignment
    Offset getAlignedOffset(Offset rawPoint, Size canvasSize) {
      double rawX = rawPoint.dx.clamp(0.0, 1.0);
      double rawY = rawPoint.dy.clamp(0.0, 1.0);

      // On-device calculations match the camera sensor matrix natively.
      // We flip horizontal X for selfie previews and map Y cleanly.
      double correctedX = (1.0 - rawX) * canvasSize.width;
      double correctedY = rawY * canvasSize.height;

      return Offset(correctedX, correctedY);
    }

    for (var points in handsPoints) {
      if (points.length < 21) continue;

      // 1. Draw the skeletal lines with aligned coordinates
      for (var connection in fingerConnections) {
        final startPoint = getAlignedOffset(points[connection[0]], size);
        final endPoint = getAlignedOffset(points[connection[1]], size);

        canvas.drawLine(startPoint, endPoint, linePaint);
      }

      // 2. Draw the tracking joints with aligned coordinates
      for (var point in points) {
        final jointPosition = getAlignedOffset(point, size);
        canvas.drawCircle(jointPosition, 7.0, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HandPainter oldDelegate) => true;
}
