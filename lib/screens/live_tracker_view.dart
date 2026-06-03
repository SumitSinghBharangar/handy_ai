import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_detection/hand_detection.dart';
import 'package:handy_ai/painters/hand_painter.dart';

class LiveTrackerView extends StatefulWidget {
  const LiveTrackerView({super.key});

  @override
  State<LiveTrackerView> createState() => _LiveTrackerViewState();
}

class _LiveTrackerViewState extends State<LiveTrackerView> {
  CameraController? _cameraController;
  HandDetector? _handDetector;

  List<List<Offset>> _trackedHands = [];
  bool _isInitialized = false;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeOfflineTracker();
  }

  Future<void> _initializeOfflineTracker() async {
    try {
      // 1. HandDetector uses an asynchronous factory creator method
      _handDetector = await HandDetector.create();

      // 2. Setup your front-facing device camera configurations
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // 3. Begin streaming camera matrices to the local engine isolate
      await _cameraController!.startImageStream((CameraImage image) {
        _processFrameOffline(image);
      });

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint("Offline initialization error: $e");
    }
  }

  void _processFrameOffline(CameraImage image) async {
    // Local copy avoids race conditions if _cameraController changes mid-execution
    final controller = _cameraController;
    if (_isDetecting ||
        !_isInitialized ||
        _handDetector == null ||
        controller == null)
      return;
    _isDetecting = true;

    try {
      // FIX: sensorOrientation is already a non-nullable int.
      // We read it directly from our safely promoted local controller.
      final int cameraRotation = controller.description.sensorOrientation;

      // 4. Use the specific native package camera stream API parameter names
      final List<Hand> hands = await _handDetector!.detectFromCameraImage(
        image,
        rotation: CameraFrameRotation.cw270,
      );

      List<List<Offset>> parsedHandsCoords = [];
      for (var hand in hands) {
        List<Offset> pointCoordinates = [];

        // Extract coordinates from the 21 localized landmark array objects
        for (var landmark in hand.landmarks) {
          // The package maps coordinates natively using standard 0.0 -> 1.0 normalization
          pointCoordinates.add(Offset(landmark.x, landmark.y));
        }
        parsedHandsCoords.add(pointCoordinates);
      }

      if (mounted) {
        setState(() {
          _trackedHands = parsedHandsCoords;
        });
      }
    } catch (e) {
      debugPrint("Offline Inference Error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _handDetector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
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
            painter: HandPainter(handsPoints: _trackedHands),
          ),
        ],
      ),
    );
  }
}
