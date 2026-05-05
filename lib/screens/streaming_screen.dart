import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_streaming/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/stream_settings_service.dart';
import '../services/youtube_live_service.dart';
import '../services/play_cricket_scraper.dart';
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
  final GlobalKey _overlayKey = GlobalKey();
  final YouTubeLiveService _ytService = YouTubeLiveService();
  bool _showOverlay = true;
  double _zoomLevel = 0;
  double _zoomMin = 0;
  double _zoomMax = 1;
  Timer? _scrapeTimer;
  String? _scorecardUrl;
  int _streamWidth = 1920;
  int _streamHeight = 1080;

  String _teamName = '';
  String _score = '';
  String _overs = '';

  String _batsman1Name = '';
  int _batsman1Runs = 0;
  int _batsman1Balls = 0;
  bool _batsman1OnStrike = true;

  String _batsman2Name = '';
  int _batsman2Runs = 0;
  int _batsman2Balls = 0;

  String _bowlerName = '';
  int _bowlerWickets = 0;
  int _bowlerRuns = 0;
  int _bowlerOvers = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _checkSettingsAndInitCamera();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrapeTimer?.cancel();
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
      _scorecardUrl = await StreamSettingsService.getScorecardUrl();

      setState(() {
        _hasSettings = hasSettings;
        _checkingSettings = false;
      });

      if (_cameras != null && _cameras!.isNotEmpty) {
        _initializeCamera(0);
      }

      // Start periodic scraping if URL is configured
      if (_scorecardUrl != null && _scorecardUrl!.isNotEmpty) {
        _fetchScoreData();
        _scrapeTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => _fetchScoreData(),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Init failed: $e';
        _checkingSettings = false;
      });
    }
  }

  Future<void> _fetchScoreData() async {
    if (_scorecardUrl == null || _scorecardUrl!.isEmpty) return;
    final data = await PlayCricketScraper.fetchMatchData(_scorecardUrl!);
    if (data == null) return;

    BowlerData? currentBowler;
    try {
      currentBowler = await PlayCricketScraper.fetchCurrentBowlerFromMatchData(data);
    } catch (_) {}

    setState(() {
      _teamName = data.battingTeam.isNotEmpty ? data.battingTeam : data.homeTeam;
      _score = data.battingScore.isNotEmpty ? data.battingScore : data.homeScore;
      _overs = data.battingOvers.isNotEmpty ? data.battingOvers : data.homeOvers;

      // Populate batsmen from API data
      if (data.batsmen.isNotEmpty) {
        final b1 = data.batsmen[0];
        _batsman1Name = b1.name;
        _batsman1Runs = b1.runs;
        _batsman1Balls = b1.balls;
        _batsman1OnStrike = true;
      }
      if (data.batsmen.length >= 2) {
        final b2 = data.batsmen[1];
        _batsman2Name = b2.name;
        _batsman2Runs = b2.runs;
        _batsman2Balls = b2.balls;
      }

      // Populate bowler from ball-by-ball API (current bowler)
      if (currentBowler != null) {
        _bowlerName = currentBowler.name;
        _bowlerWickets = currentBowler.wickets;
        _bowlerRuns = currentBowler.runs;
        _bowlerOvers = currentBowler.overs;
      } 
    });

    if (_isStreaming) {
      await _updateStreamOverlay();
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
      final resolution = await StreamSettingsService.getResolution();
      _cameraController = CameraController(
        resolution,
        enableAudio: true,
      );
      await _cameraController!.initialize(_cameras![cameraIndex]);
      await _loadZoomRange();
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

    if (!_ytService.isSignedIn) {
      _showSnack('Please sign in to YouTube first');
      return;
    }

    _showSnack('Creating YouTube broadcast...');
    final url = await _ytService.createAndBindStream(
      title: 'De Beauvoir Dugongs Live - ${DateTime.now().toIso8601String().substring(0, 10)}',
    );
    if (url == null) {
      _showSnack('Failed to create YouTube broadcast');
      return;
    }

    try {
      await _updateStreamOverlay();
      final bitrate = await StreamSettingsService.getBitrate();
      final encoderStr = await StreamSettingsService.getVideoEncoder();
      final encoder = encoderStr == 'h265'
          ? VideoEncoder.h265
          : encoderStr == 'av1'
              ? VideoEncoder.av1
              : VideoEncoder.h264;
      debugPrint('Setting video encoder: $encoderStr');
      await _cameraController!.setVideoEncoder(encoder);
      debugPrint('Starting stream with bitrate: $bitrate');
      await _cameraController!.startVideoStreaming(url, bitrate: bitrate);
      setState(() => _isStreaming = true);
    } catch (e) {
      _showSnack('Stream error: $e');
    }
  }

  Future<void> _signInYouTube() async {
    final success = await _ytService.signIn();
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

  void _showCameraPicker() {
    if (_cameras == null || _cameras!.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) {
        int backCount = 0;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _cameras!.asMap().entries.map((entry) {
              final i = entry.key;
              final cam = entry.value;
              String label;
              if (cam.lensDirection == CameraLensDirection.front) {
                label = 'Front';
              } else {
                backCount++;
                label = 'Back $backCount';
              }
              final selected = i == _currentCameraIndex;
              return ListTile(
                selected: selected,
                selectedTileColor: Colors.red.withValues(alpha: 0.2),
                leading: Icon(
                  cam.lensDirection == CameraLensDirection.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: selected ? Colors.red : Colors.white,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.red : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected ? const Icon(Icons.check_circle, color: Colors.red) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (i != _currentCameraIndex) _selectCamera(i);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _selectCamera(int index) async {
    if (_isSwitchingCamera) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized!) return;

    _isSwitchingCamera = true;
    try {
      await _cameraController!.switchCamera(_cameras![index].name!);
      setState(() => _currentCameraIndex = index);
      await _loadZoomRange();
    } catch (e) {
      _showSnack('Camera switch failed: $e');
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _loadZoomRange() async {
    try {
      final range = await _cameraController!.getZoomRange();
      setState(() {
        _zoomMin = range['min']!;
        _zoomMax = range['max']!;
        _zoomLevel = _zoomMin;
      });
    } catch (_) {}
  }

  Future<void> _updateStreamOverlay() async {
    if (_cameraController == null || !_isInitialized) return;

    try {
      final dims = await StreamSettingsService.getStreamDimensions();
      _streamWidth = dims.$1;
      _streamHeight = dims.$2;

      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture the overlay widget at high resolution
      final overlayImage = await boundary.toImage(pixelRatio: 2.0);
      final overlayWidth = overlayImage.width.toDouble();
      final overlayHeight = overlayImage.height.toDouble();

      final streamWidth = _streamWidth.toDouble();
      final streamHeight = _streamHeight.toDouble();

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
      final fullImage = await picture.toImage(_streamWidth, _streamHeight);
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

    if (!_hasSettings) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No scorecard URL configured', style: TextStyle(fontSize: 18)),
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
          // Camera preview - fills entire screen
          if (_isInitialized && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator()),

          if (_showOverlay)
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
                          icon: Icon(
                            _showOverlay ? Icons.layers : Icons.layers_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => _showOverlay = !_showOverlay),
                          tooltip: _showOverlay ? 'Hide overlay' : 'Show overlay',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: _cameras != null && _cameras!.length > 1 ? _showCameraPicker : null,
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

          // Zoom slider
          if (_isInitialized && _zoomMax > _zoomMin)
            Positioned(
              right: 16,
              top: 80,
              bottom: 140,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _zoomLevel.clamp(_zoomMin, _zoomMax),
                  min: _zoomMin,
                  max: _zoomMax,
                  activeColor: Colors.red,
                  inactiveColor: Colors.white30,
                  onChanged: (v) {
                    setState(() => _zoomLevel = v);
                    _cameraController?.setZoom(v);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
