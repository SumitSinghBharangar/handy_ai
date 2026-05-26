import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handy_ai/painters/hand_painter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  CameraController? _cameraController;
  Interpreter? _palmInterpreter;
  Interpreter? _landmarkInterpreter;

  List<Offset> _points = [];
  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _isFrontCamera = true;
  bool _isPipelineLoading = false;
  String _statusText = "Loading TFLite Files...";

  late TensorType _palmInputType;
  late TensorType _landmarkInputType;

  // Track dynamic dimensions of output shapes
  late List<int> _palmOutputShape;
  late List<int> _landmarkOutputShape;

  @override
  void initState() {
    super.initState();
    _loadModelsAndCamera();
  }

  Future<void> _loadModelsAndCamera() async {
    if (_isPipelineLoading) return;
    _isPipelineLoading = true;

    try {
      _palmInterpreter = await Interpreter.fromAsset(
        'assets/models/palm_detection.tflite',
      );
      _landmarkInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark.tflite',
      );

      // 1. Cache the input memory types expected by your models
      _palmInputType = _palmInterpreter!.getInputTensors().first.type;
      _landmarkInputType = _landmarkInterpreter!.getInputTensors().first.type;

      // 2. SELF-CORRECTION STEP: Get the exact structural shapes expected for outputs
      _palmOutputShape = _palmInterpreter!.getOutputTensors().first.shape;
      _landmarkOutputShape = _landmarkInterpreter!
          .getOutputTensors()
          .first
          .shape;

      debugPrint("PALM OUTPUT MODEL EXHAUSTIVE SHAPE: $_palmOutputShape");
      debugPrint(
        "LANDMARK OUTPUT MODEL EXHAUSTIVE SHAPE: $_landmarkOutputShape",
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _isFrontCamera = frontCam.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream((CameraImage image) {
        _runInferenceOnFrame(image);
      });

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusText = "Models Active & Running ✅";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = "Error Initializing Setup ❌");
      }
      debugPrint("Initialization failure error: $e");
    } finally {
      _isPipelineLoading = false;
    }
  }

  // Returns a flat binary array matching the exact expected memory layout size
  Uint8List _convertImageToRawBytes(
    img.Image image,
    int targetSize,
    TensorType type,
  ) {
    img.Image resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
    );

    if (type == TensorType.float32) {
      var floatBuffer = Float32List(targetSize * targetSize * 3);
      int index = 0;
      for (int y = 0; y < targetSize; y++) {
        for (int x = 0; x < targetSize; x++) {
          final pixel = resized.getPixel(x, y);
          floatBuffer[index++] = pixel.r / 255.0;
          floatBuffer[index++] = pixel.g / 255.0;
          floatBuffer[index++] = pixel.b / 255.0;
        }
      }
      return floatBuffer.buffer.asUint8List();
    } else {
      var byteBuffer = Uint8List(targetSize * targetSize * 3);
      int index = 0;
      for (int y = 0; y < targetSize; y++) {
        for (int x = 0; x < targetSize; x++) {
          final pixel = resized.getPixel(x, y);
          byteBuffer[index++] = pixel.r.toInt();
          byteBuffer[index++] = pixel.g.toInt();
          byteBuffer[index++] = pixel.b.toInt();
        }
      }
      return byteBuffer;
    }
  }

  // Helper utility to dynamically generate empty output arrays using TFLite structural rules
  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.length == 2) {
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    } else if (shape.length == 3) {
      return List.generate(
        shape[0],
        (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
      );
    } else {
      return List.filled(shape.reduce((a, b) => a * b), 0.0);
    }
  }

  void _runInferenceOnFrame(CameraImage cameraImage) async {
    if (_isDetecting ||
        _palmInterpreter == null ||
        _landmarkInterpreter == null)
      return;
    _isDetecting = true;

    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final img.Image baseImage = img.Image(width: width, height: height);

      final Uint8List yBytes = cameraImage.planes[0].bytes;
      int pIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (pIndex < yBytes.length) {
            final int grayValue = yBytes[pIndex++];
            baseImage.setPixelRgb(x, y, grayValue, grayValue, grayValue);
          }
        }
      }

      // --- 1. RUN PALM DETECTION ---
      final palmBytes = _convertImageToRawBytes(baseImage, 192, _palmInputType);
      _palmInterpreter!.getInputTensor(0).setTo(palmBytes);
      _palmInterpreter!.invoke();

      // Dynamically create an output matrix that matches the model exactly
      var palmOutput = _createOutputBuffer(_palmOutputShape);
      _palmInterpreter!.getOutputTensor(0).copyTo(palmOutput);

      // --- 2. RUN HAND LANDMARK ---
      final landmarkBytes = _convertImageToRawBytes(
        baseImage,
        256,
        _landmarkInputType,
      );
      _landmarkInterpreter!.getInputTensor(0).setTo(landmarkBytes);
      _landmarkInterpreter!.invoke();

      // Dynamically create an output matrix that matches the landmark model exactly
      var landmarkOutput = _createOutputBuffer(_landmarkOutputShape);
      _landmarkInterpreter!.getOutputTensor(0).copyTo(landmarkOutput);

      // --- 3. DYNAMIC SAFE COORD EXTRACTION ---
      List<Offset> extractedPoints = [];

      // Flatten the output to parse out coordinates safely regardless of shape variants
      List<double> flatCoords = [];
      void flatten(dynamic list) {
        if (list is List) {
          for (var item in list) {
            flatten(item);
          }
        } else if (list is double) {
          flatCoords.add(list);
        }
      }

      flatten(landmarkOutput);

      // Extract the 21 landmarks (each has X, Y, and Z values)
      if (flatCoords.length >= 63) {
        for (int i = 0; i < 21; i++) {
          double rawX = flatCoords[i * 3];
          double rawY = flatCoords[i * 3 + 1];

          extractedPoints.add(
            Offset(rawX.clamp(0.0, 1.0), rawY.clamp(0.0, 1.0)),
          );
        }
      }

      if (mounted) {
        setState(() {
          _points = extractedPoints;
        });
      }
    } catch (e) {
      debugPrint("Inference Exception Solved: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _palmInterpreter?.close();
    _landmarkInterpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          CustomPaint(
            size: Size.infinite,
            painter: HandPainter(
              points: _points,
              isFrontCamera: _isFrontCamera,
            ),
          ),
        ],
      ),
    );
  }
}
