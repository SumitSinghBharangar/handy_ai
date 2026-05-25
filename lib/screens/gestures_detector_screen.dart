import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:handy_ai/painters/pose_painter.dart';
import '../painters/hand_painter.dart';

late List<CameraDescription> cameras;

class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  late CameraController controller;

  bool isCameraReady = false;
  bool isDetecting = false;
  Timer? detectionTimer;

  final poseDetector = PoseDetector(options: PoseDetectorOptions());

  List<Pose> poses = [];

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();

    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    startDetectionLoop();

    if (!mounted) return;

    setState(() {
      isCameraReady = true;
    });
  }

  void startDetectionLoop() {
    detectionTimer = Timer.periodic(const Duration(milliseconds: 30), (
      _,
    ) async {
      if (isDetecting) return;

      isDetecting = true;

      await captureAndDetect();
    });
  }

  Future<void> captureAndDetect() async {
    try {
      final XFile file = await controller.takePicture();

      final inputImage = InputImage.fromFilePath(file.path);

      final detectedPoses = await poseDetector.processImage(inputImage);

      poses = detectedPoses;

      setState(() {});
    } catch (e) {
      print(e);
    }

    isDetecting = false;
  }

  @override
  void dispose() {
    controller.dispose();
    detectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isCameraReady
          ? Stack(
              children: [
                SizedBox.expand(child: CameraPreview(controller)),

                CustomPaint(size: Size.infinite, painter: PosePainter(poses)),

                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,

                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: const Text(
                        "Camera Working ✅",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
