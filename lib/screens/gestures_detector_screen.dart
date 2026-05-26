import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handy_ai/painters/skeleton_painter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveTrackerView extends StatefulWidget {
  const LiveTrackerView({super.key});

  @override
  State<LiveTrackerView> createState() => _LiveTrackerViewState();
}

class _LiveTrackerViewState extends State<LiveTrackerView> {
  CameraController? _cameraController;
  WebSocketChannel? _wsChannel;

  List<List<Offset>> _trackedHands = [];
  bool _isPipelineReady = false;
  bool _isSendingFrame = false;

  // REPLACE THIS WITH YOUR COMPUTER'S IP ADDRESS
  final String _pcIpAddress = "10.62.195.65";

  @override
  void initState() {
    super.initState();
    _initializePipeline();
  }

  Future<void> _initializePipeline() async {
    try {
      final String wsUrl = "ws://$_pcIpAddress:8000/ws/hand-tracking";
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (message) {
          final Map<String, dynamic> response = jsonDecode(message);
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
            });
          }
        },
        onError: (error) {
          debugPrint("WebSocket Error: $error");
        },
      );

      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset
            .medium, // Medium resolution ensures lightning fast network streaming
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Start streaming video frames from the camera
      await _cameraController!.startImageStream((CameraImage image) {
        _streamFrameToBackend(image);
      });

      setState(() => _isPipelineReady = true);
    } catch (e) {
      debugPrint("Pipeline setup failure: $e");
    }
  }

  void _streamFrameToBackend(CameraImage image) async {
    if (_isSendingFrame || _wsChannel == null) return;
    _isSendingFrame = true;

    try {
      // FIX: Instead of raw planes, we use the controller's highly optimized native method
      // to capture a snapshot file frame, which is globally guaranteed to be a true compressed JPEG
      XFile capturedFile = await _cameraController!.takePicture();

      // Read the true JPEG binary array data
      final bytes = await capturedFile.readAsBytes();

      // Blast the valid JPEG data directly down the websocket channel
      _wsChannel!.sink.add(bytes);
    } catch (e) {
      debugPrint("Failed to push image payload: $e");
    } finally {
      _isSendingFrame = false;
    }
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
            painter: SkeletonPainter(handsPoints: _trackedHands),
          ),
        ],
      ),
    );
  }
}
