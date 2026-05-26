import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class LandmarkPainter extends CustomPainter {
  final List<Hand> hands;
  final bool isFrontCamera;

  LandmarkPainter({required this.hands, required this.isFrontCamera});

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    Offset scalePoint(Landmark point) {
      // Scale from normalized 0.0-1.0 mapping to actual UI pixel constraints
      double x = point.x * size.width;
      double y = point.y * size.height;

      if (isFrontCamera) {
        x = size.width - x; // Mirror layout coordinates for front lens
      }
      return Offset(x, y);
    }

    // MediaPipe Hands skeletal structure mapping array
    final connections = [
      [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
      [0, 5], [5, 6], [6, 7], [7, 8], // Index
      [9, 10], [10, 11], [11, 12],    // Middle
      [13, 14], [14, 15], [15, 16],   // Ring
      [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
      [5, 9], [9, 13], [13, 17]       // Knuckle connection line
    ];

    for (var hand in hands) {
      // Draw Skeleton Lines
      for (var connection in connections) {
        final p1 = hand.landmarks[connection[0]];
        final p2 = hand.landmarks[connection[1]];
        canvas.drawLine(scalePoint(p1), scalePoint(p2), linePaint);
      }

      // Draw Joint Dots
      for (var point in hand.landmarks) {
        canvas.drawCircle(scalePoint(point), 5.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) {
    return oldDelegate.hands != hands;
  }
}