import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handy_ai/painters/skeleton_painter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class GesturesDetectorScreen extends StatefulWidget {
  const GesturesDetectorScreen({super.key});

  @override
  State<GesturesDetectorScreen> createState() => _GesturesDetectorScreenState();
}

class _GesturesDetectorScreenState extends State<GesturesDetectorScreen> {
  CameraController? _cameraController;
  WebSocketChannel? _wsChannel;

  List<List<Offset>> _trackedHands = [];
  String _detectedGesture = "AWAITING HAND..."; // Dynamic gesture name tracker
  bool _isPipelineReady = false;
  bool _isSendingFrame = false;

  String _pcIpAddress = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIpConfigDialog();
    });
  }

  void _showIpConfigDialog() {
    final TextEditingController ipController = TextEditingController(
      text: _pcIpAddress.isEmpty ? "10.93.195.65" : _pcIpAddress,
    );

    showDialog(
      context: context,
      barrierDismissible: _pcIpAddress.isNotEmpty,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.gesture, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                "Gesture System Engine",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: TextField(
            controller: ipController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Enter Computer IPv4 Address",
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyanAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (ipController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  if (_isPipelineReady) {
                    _cameraController?.stopImageStream();
                    _wsChannel?.sink.close();
                    setState(() {
                      _isPipelineReady = false;
                      _trackedHands = [];
                    });
                  }
                  _pcIpAddress = ipController.text.trim();
                  _initializePipeline();
                }
              },
              child: const Text(
                "Launch Engine",
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializePipeline() async {
    try {
      final String wsUrl = "ws://$_pcIpAddress:8000/ws/hand-tracking";
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen((message) {
        final Map<String, dynamic> response = jsonDecode(message);

        // 1. Extract the Expression name text parsed by Python
        final String expression = response['gesture'] ?? "TRACKING...";

        // 2. Extract standard structural coordinates arrays
        final List<dynamic> handsData = response['hands'];
        List<List<Offset>> parsedHands = [];
        for (var hand in handsData) {
          List<Offset> points = [];
          for (var landmark in hand) {
            points.add(Offset(landmark['x'], landmark['y']));
          }
          parsedHands.add(points);
        }

        if (mounted) {
          setState(() {
            _trackedHands = parsedHands;
            _detectedGesture = expression; // Update our display state
          });
        }
      }, onError: (error) => debugPrint("WebSocket Error: $error"));

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
      await _cameraController!.startImageStream(
        (CameraImage image) => _streamFrameToBackend(image),
      );

      setState(() => _isPipelineReady = true);
    } catch (e) {
      debugPrint("Pipeline Error: $e");
    }
  }

  void _streamFrameToBackend(CameraImage image) async {
    if (_isSendingFrame || _wsChannel == null) return;
    _isSendingFrame = true;
    try {
      XFile capturedFile = await _cameraController!.takePicture();
      final bytes = await capturedFile.readAsBytes();
      _wsChannel!.sink.add(bytes);
    } catch (e) {
      debugPrint("Payload error: $e");
    } finally {
      _isSendingFrame = false;
    }
  }

  // Returns different neon accent colors depending on which expression is active
  Color _getExpressionColor() {
    if (_detectedGesture.contains("VICTORY")) return Colors.purpleAccent;
    if (_detectedGesture.contains("FIST")) return Colors.redAccent;
    if (_detectedGesture.contains("PALM")) return Colors.greenAccent;
    if (_detectedGesture.contains("THUMBS")) return Colors.amberAccent;
    if (_detectedGesture.contains("POINTING")) return Colors.blueAccent;
    return Colors.cyanAccent;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPipelineReady || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent),
              const SizedBox(height: 15),
              Text(
                "Booting Up Pipeline at $_pcIpAddress...",
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    Color activeColor = _getExpressionColor();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          CustomPaint(
            size: Size.infinite,
            painter: SkeletonPainter(handsPoints: _trackedHands),
          ),

          // --- NEON GLOW COLORFUL TEXT OVERLAY LAYER ---
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: activeColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _detectedGesture,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: activeColor, blurRadius: 10)],
                ),
              ),
            ),
          ),

          // Settings Button
          Positioned(
            bottom: 40,
            right: 30,
            child: CircleAvatar(
              backgroundColor: Colors.black,
              radius: 28,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.cyanAccent,
                  size: 28,
                ),
                onPressed: _showIpConfigDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
