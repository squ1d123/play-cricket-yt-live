import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_streaming/camera.dart';
import '../services/stream_settings_service.dart';
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
  bool _showCameraSelector = false;
  bool _isSwitchingCamera = false;
  int _currentCameraIndex = 0;
  String? _error;
  String? _rtmpUrl;

  String _teamName = 'De Beauville Dugongs';
  String _score = '166/4 (16.4)';
  String _result = '20 overs remain';

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
      
      debugPrint('Available cameras: ${_cameras?.map((c) => c.name).toList()}');
      
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
    
    setState(() {
      _isInitialized = false;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      _cameraController = CameraController(
        ResolutionPreset.ultraHigh,
        enableAudio: true,
      );

      await _cameraController!.initialize(_cameras![cameraIndex]);
      setState(() {
        _isInitialized = true;
        _currentCameraIndex = cameraIndex;
      });
    } catch (e) {
      setState(() {
        _error = 'Camera init failed: $e';
      });
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _toggleStreaming() async {
    if (_cameraController == null || _cameraController!.value.isInitialized == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not ready')),
        );
      }
      return;
    }

    if (_isStreaming) {
      await _cameraController!.stopVideoStreaming();
      setState(() => _isStreaming = false);
    } else {
      if (_rtmpUrl == null || !_rtmpUrl!.contains('live2')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please configure stream settings first')),
          );
        }
        return;
      }
      
      try {
        await _updateStreamOverlay();
        await _cameraController!.startVideoStreaming(
          _rtmpUrl!,
          bitrate: 4500 * 1024,
        );
        setState(() => _isStreaming = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stream error: $e')),
          );
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    if (_isSwitchingCamera) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized!) return;
    
    _isSwitchingCamera = true;
    
    try {
      final newIndex = (_currentCameraIndex + 1) % _cameras!.length;
      final cameraName = _cameras![newIndex].name;
      
      await _cameraController!.switchCamera(cameraName!);
      
      setState(() {
        _currentCameraIndex = newIndex;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera switch failed: $e')),
        );
      }
    } finally {
      _isSwitchingCamera = false;
    }
  }

  void _toggleCameraSelector() {
    setState(() => _showCameraSelector = !_showCameraSelector);
  }

  Future<void> _updateStreamOverlay() async {
    if (_cameraController == null || !_isInitialized) return;

    final overlay = await _renderOverlayBitmap();
    if (overlay == null) return;

    final cacheDir = await getApplicationDocumentsDirectory();
    final file = File('${cacheDir.path}/stream_overlay.png');
    await file.writeAsBytes(overlay);

    await _cameraController!.setFilter(23, filePath: file.path);
  }

  Future<List<int>?> _renderOverlayBitmap() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 1920.0;
    const height = 1080.0;
    const scale = width / 1920;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.transparent,
    );

    final texts = <_OverlayLine>[];
    if (_teamName.isNotEmpty) texts.add(_OverlayLine(_teamName.toUpperCase(), 36 * scale, Colors.white, FontWeight.bold));
    if (_score.isNotEmpty) texts.add(_OverlayLine(_score, 64 * scale, Colors.white, FontWeight.bold));
    if (_result.isNotEmpty) texts.add(_OverlayLine(_result.toUpperCase(), 28 * scale, Colors.orange, FontWeight.normal));

    if (texts.isEmpty) return null;

    const baseX = 32.0 * scale;
    const baseY = 80.0 * scale;
    const paddingH = 32.0 * scale;
    const paddingV = 24.0 * scale;
    const cornerRadius = 16.0 * scale;
    const lineHeight = 48.0 * scale;
    const spacing = 8.0 * scale;

    final maxTextWidth = texts.map((t) => _measureText(canvas, t.text, t.fontSize)).reduce((a, b) => a > b ? a : b);
    final totalHeight = texts.length * lineHeight + (texts.length - 1) * spacing;
    final rectWidth = maxTextWidth + paddingH * 2;
    final rectHeight = totalHeight + paddingV * 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(baseX, baseY, rectWidth, rectHeight),
        Radius.circular(cornerRadius),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );

    var currentY = baseY + paddingV + lineHeight * 0.7;
    for (final line in texts) {
      final tp = TextPainter(
        text: TextSpan(text: line.text, style: TextStyle(fontSize: line.fontSize, color: line.color, fontWeight: line.fontWeight)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(baseX + paddingH, currentY));
      currentY += lineHeight + spacing;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  double _measureText(Canvas canvas, String text, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  String get _currentCameraLabel {
    if (_cameras == null || _currentCameraIndex >= _cameras!.length) return 'Camera';
    final dir = _cameras![_currentCameraIndex].lensDirection;
    if (dir == CameraLensDirection.front) return 'Selfie';
    return 'Back ${_currentCameraIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSettings) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!_hasSettings) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No stream settings configured',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please add your YouTube stream key first',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
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
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          CricketScoreOverlay(
            teamName: _teamName,
            score: _score,
            result: _result,
          ),
          
          Positioned(
            top: 90,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$_currentCameraLabel (${_cameras?.length ?? 0} cams)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isStreaming ? Colors.red : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isStreaming 
                                ? Icons.fiber_manual_record 
                                : Icons.circle_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isStreaming ? 'LIVE' : 'OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                      onPressed: _cameras != null && _cameras!.length > 1 ? _switchCamera : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showCameraSelector && _cameras != null && _cameras!.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Camera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _currentCameraLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: (_currentCameraIndex + 1).toDouble(),
                              min: 1,
                              max: _cameras!.length.toDouble(),
                              divisions: _cameras!.length - 1,
                              activeColor: Colors.red,
                              inactiveColor: Colors.white30,
                              onChanged: (v) => _initializeCamera(v.toInt() - 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showCameraSelector ? Icons.cameraswitch : Icons.select_all,
                            color: Colors.white,
                          ),
                          onPressed: _cameras != null && _cameras!.length > 1 ? _toggleCameraSelector : null,
                        ),
                        GestureDetector(
                          onTap: _toggleStreaming,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isStreaming ? Colors.red : Colors.white,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: Icon(
                              _isStreaming ? Icons.stop : Icons.play_arrow,
                              size: 40,
                              color: _isStreaming ? Colors.white : Colors.red,
                            ),
                          ),
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
        ],
      ),
    );
  }
}

class _OverlayLine {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  _OverlayLine(this.text, this.fontSize, this.color, this.fontWeight);
}
