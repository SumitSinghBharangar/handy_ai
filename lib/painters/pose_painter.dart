// import 'package:flutter/material.dart';


// class PosePainter extends CustomPainter {


//   PosePainter(this.poses);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final pointPaint = Paint()
//       ..color = Colors.greenAccent
//       ..style = PaintingStyle.fill;

//     for (final pose in poses) {
//       for (final landmark in pose.landmarks.values) {
//         canvas.drawCircle(Offset(landmark.x, landmark.y), 8, pointPaint);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return true;
//   }
// }
