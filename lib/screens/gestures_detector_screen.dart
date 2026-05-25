import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:handy_ai/painters/pose_painter.dart';
import 'package:handy_ai/services/hand_detector_service.dart';
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

  final handDetector = HandDetectorService();

  String statusText = "Initializing...";

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      // LOAD AI MODEL

      await handDetector.loadModel();

      // GET CAMERAS

      cameras = await availableCameras();

      // FRONT CAMERA

      controller = CameraController(
        cameras.first,

        ResolutionPreset.medium,

        enableAudio: false,
      );

      // INITIALIZE CAMERA

      await controller.initialize();

      // START DETECTION LOOP

      startDetectionLoop();

      if (!mounted) return;

      setState(() {
        isCameraReady = true;

        statusText = "Hand AI Ready ✅";
      });
    } catch (e) {
      print(e);

      statusText = "Camera Error ❌";
    }
  }

  void startDetectionLoop() {
    detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (isDetecting) return;

      isDetecting = true;

      await runHandDetection();
    });
  }

  Future<void> runHandDetection() async {
    try {
      final XFile image = await controller.takePicture();

      print("Frame Captured: ${image.path}");

      // NEXT STEP:
      // AI HAND DETECTION WILL RUN HERE

      setState(() {
        statusText = "Detecting Hand...";
      });
    } catch (e) {
      print(e);

      setState(() {
        statusText = "Detection Failed ❌";
      });
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.greenAccent,
                          width: 1.5,
                        ),
                      ),

                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,

                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundColor: Colors.greenAccent,
                        ),

                        SizedBox(width: 10),
                        Text(
                          "AI ACTIVE",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
