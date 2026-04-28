import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_streaming/camera.dart';
import '../services/stream_settings_service.dart';
import '../services/youtube_live_service.dart';
import '../widgets/cricket_score_overlay.dart';

class StreamingScreen extends StatefulWidget {
  const StreamingScreen({super.key});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _hasSettings = false;
  bool _checkingSettings = true;
  bool _isSwitchingCamera = false;
  int _currentCameraIndex = 0;
  String? _error;
  String? _rtmpUrl;
  final GlobalKey _overlayKey = GlobalKey();
  final YouTubeLiveService _ytService = YouTubeLiveService();
  bool _useYouTubeApi = false;

  // ignore: prefer_final_fields - these will be updated by web scraper
  String _teamName = 'De Beauville Dugongs';
  String _score = '166/4';
  String _overs = '16.4';

  String _batsman1Name = 'John Smith';
  int _batsman1Runs = 45;
  int _batsman1Balls = 32;
  bool _batsman1OnStrike = true;

  String _batsman2Name = 'Mike Jones';
  int _batsman2Runs = 23;
  int _batsman2Balls = 18;

  String _bowlerName = 'Sameer Magan';
  int _bowlerWickets = 1;
  int _bowlerRuns = 22;
  int _bowlerOvers = 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _checkSettingsAndInitCamera();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkSettingsAndInitCamera() async {
    try {
      _cameras = await availableCameras();
      final hasSettings = await StreamSettingsService.hasSettings();
      _rtmpUrl = await StreamSettingsService.getFullRtmpUrl();

      setState(() {
        _hasSettings = hasSettings;
        _checkingSettings = false;
      });

      if (_cameras != null && _cameras!.isNotEmpty) {
        _initializeCamera(0);
      }
    } catch (e) {
      setState(() {
        _error = 'Init failed: $e';
        _checkingSettings = false;
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_cameras == null || cameraIndex >= _cameras!.length) return;
    if (_isSwitchingCamera) return;

    _isSwitchingCamera = true;

    if (_cameraController != null) {
      if (_isStreaming) {
        await _cameraController!.stopVideoStreaming();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }

    setState(() => _isInitialized = false);
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      _cameraController = CameraController(
        ResolutionPreset.veryHigh,
        enableAudio: true,
      );
      await _cameraController!.initialize(_cameras![cameraIndex]);
      setState(() {
        _isInitialized = true;
        _currentCameraIndex = cameraIndex;
      });
    } catch (e) {
      setState(() => _error = 'Camera init failed: $e');
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _toggleStreaming() async {
    if (_cameraController == null || _cameraController!.value.isInitialized == false) {
      _showSnack('Camera not ready');
      return;
    }

    if (_isStreaming) {
      await _cameraController!.stopVideoStreaming();
      setState(() => _isStreaming = false);
      return;
    }

    // Determine RTMP URL
    String? url = _rtmpUrl;
    if (_useYouTubeApi) {
      _showSnack('Creating YouTube broadcast...');
      url = await _ytService.createAndBindStream(
        title: 'De Beauvoir Dugongs Live - ${DateTime.now().toIso8601String().substring(0, 10)}',
      );
      if (url == null) {
        _showSnack('Failed to create YouTube broadcast');
        return;
      }
    }

    if (url == null || url.isEmpty) {
      _showSnack('Please configure stream settings first');
      return;
    }

    try {
      await _updateStreamOverlay();
      await _cameraController!.startVideoStreaming(url, bitrate: 4500 * 1024);
      setState(() => _isStreaming = true);
    } catch (e) {
      _showSnack('Stream error: $e');
    }
  }

  Future<void> _signInYouTube() async {
    final success = await _ytService.signIn();
    setState(() => _useYouTubeApi = success);
    _showSnack(success ? 'YouTube connected' : 'YouTube sign-in failed');
    // Re-initialize camera after sign-in activity returns
    if (success && _cameras != null && _cameras!.isNotEmpty) {
      await _initializeCamera(_currentCameraIndex);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    if (_isSwitchingCamera) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized!) return;

    _isSwitchingCamera = true;
    try {
      final newIndex = (_currentCameraIndex + 1) % _cameras!.length;
      await _cameraController!.switchCamera(_cameras![newIndex].name!);
      setState(() => _currentCameraIndex = newIndex);
    } catch (e) {
      _showSnack('Camera switch failed: $e');
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _updateStreamOverlay() async {
    if (_cameraController == null || !_isInitialized) return;

    try {
      // Wait for the overlay to be laid out
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture the overlay widget at high resolution
      final overlayImage = await boundary.toImage(pixelRatio: 2.0);
      final overlayWidth = overlayImage.width.toDouble();
      final overlayHeight = overlayImage.height.toDouble();

      // Create a full 1920x1080 transparent canvas with overlay at the bottom
      const streamWidth = 1920.0;
      const streamHeight = 1080.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Scale overlay to fill full width of stream
      final scaleX = streamWidth / overlayWidth;
      final scaledHeight = overlayHeight * scaleX;
      final yOffset = streamHeight - scaledHeight;

      canvas.save();
      canvas.translate(0, yOffset);
      canvas.scale(scaleX, scaleX);
      canvas.drawImage(overlayImage, Offset.zero, Paint());
      canvas.restore();

      final picture = recorder.endRecording();
      final fullImage = await picture.toImage(1920, 1080);
      final byteData = await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final cacheDir = await getApplicationDocumentsDirectory();
      final file = File('${cacheDir.path}/stream_overlay.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await _cameraController!.setFilter(23, filePath: file.path);
    } catch (e) {
      debugPrint('Overlay capture failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSettings) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!)),
      );
    }

    if (!_hasSettings && !_useYouTubeApi) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No stream settings configured', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _signInYouTube,
                  icon: const Icon(Icons.login),
                  label: const Text('SIGN IN WITH YOUTUBE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview - fills entire screen
          if (_isInitialized && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator()),

          // Overlay preview - visible on screen AND captured for stream
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              key: _overlayKey,
              child: CricketScoreOverlay(
                teamName: _teamName,
                score: _score,
                overs: _overs,
                batsman1Name: _batsman1Name,
                batsman1Runs: _batsman1Runs,
                batsman1Balls: _batsman1Balls,
                batsman1OnStrike: _batsman1OnStrike,
                batsman2Name: _batsman2Name,
                batsman2Runs: _batsman2Runs,
                batsman2Balls: _batsman2Balls,
                bowlerName: _bowlerName,
                bowlerWickets: _bowlerWickets,
                bowlerRuns: _bowlerRuns,
                bowlerOvers: _bowlerOvers,
              ),
            ),
          ),

          // Top bar - status + controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isStreaming ? Colors.red : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isStreaming ? Icons.fiber_manual_record : Icons.circle_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isStreaming ? 'LIVE' : 'OFFLINE',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (_ytService.isSignedIn)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ),
                        if (!_ytService.isSignedIn)
                          IconButton(
                            icon: const Icon(Icons.login, color: Colors.white),
                            onPressed: _signInYouTube,
                            tooltip: 'Sign in to YouTube',
                          ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: _cameras != null && _cameras!.length > 1 ? _switchCamera : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleStreaming,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isStreaming ? Colors.red : Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Icon(
                    _isStreaming ? Icons.stop : Icons.play_arrow,
                    size: 36,
                    color: _isStreaming ? Colors.white : Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
