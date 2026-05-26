import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class HandDetectorService {
  Interpreter? interpreter;

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/models/palm_detection.tflite',
      );

      debugPrint("MODEL LOADED SUCCESSFULLY ✅");
    } catch (e) {
      debugPrint("MODEL LOAD ERROR ❌");

      debugPrint("$e");
    }
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (interpreter == null) {
      debugPrint("Interpreter is NULL ❌");

      return;
    }

    try {
      // CONVERT CAMERA IMAGE TO RGB

      img.Image rgbImage = convertYUV420ToImage(image);

      // RESIZE FOR MODEL

      img.Image resizedImage = img.copyResize(
        rgbImage,
        width: 192,
        height: 192,
      );

      // CREATE INPUT TENSOR

      var input = List.generate(
        1,
        (_) => List.generate(
          192,
          (y) => List.generate(192, (x) {
            final pixel = resizedImage.getPixel(x, y);

            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      );

      // OUTPUT BUFFER

      var output = List.generate(
        1,
        (_) => List.generate(2016, (_) => List.filled(18, 0.0)),
      );

      // RUN MODEL

      interpreter?.run(input, output);

      debugPrint("Inference Running ✅");
    } catch (e) {
      debugPrint("$e");
    }
  }

  img.Image convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final uvRowStride = image.planes[1].bytesPerRow;

    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    var imgBuffer = img.Image(width: width, height: height);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);

        final index = y * width + x;

        final yp = image.planes[0].bytes[index];

        if (uvIndex >= image.planes[1].bytes.length ||
            uvIndex >= image.planes[2].bytes.length) {
          continue;
        }

        final up = image.planes[1].bytes[uvIndex] - 128;

        final vp = image.planes[2].bytes[uvIndex] - 128;

        int r = (yp + vp * 1436 / 1024).round();

        int g = (yp - up * 46549 / 131072 - vp * 93604 / 131072).round();

        int b = (yp + up * 1814 / 1024).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }

    return imgBuffer;
  }
}
