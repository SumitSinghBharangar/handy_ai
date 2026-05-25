import 'package:tflite_flutter/tflite_flutter.dart';

class HandDetectorService {
  Interpreter? interpreter;

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset(
      'assets/models/palm_detection.tflite',
    );

    print("Hand Model Loaded ✅");
  }
}
