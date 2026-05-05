import 'package:flutter/material.dart';
import '../services/stream_settings_service.dart';
import '../services/play_cricket_scraper.dart';
import '../services/stream_settings_service.dart' show BitratePreset;
import '../services/youtube_live_service.dart';

class StreamSettingsScreen extends StatefulWidget {
  const StreamSettingsScreen({super.key});

  @override
  State<StreamSettingsScreen> createState() => _StreamSettingsScreenState();
}

class _StreamSettingsScreenState extends State<StreamSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rtmpUrlController = TextEditingController();
  final _streamKeyController = TextEditingController();
  final _scorecardUrlController = TextEditingController();
  final _bitrateController = TextEditingController();
  final _resolutionController = TextEditingController();
  final _ytService = YouTubeLiveService();
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  String? _ytAccountEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final rtmpUrl = await StreamSettingsService.getRtmpUrl();
    final streamKey = await StreamSettingsService.getStreamKey();
    final scorecardUrl = await StreamSettingsService.getScorecardUrl();
    final bitrate = await StreamSettingsService.getBitrate();
    final resolutionIndex = await StreamSettingsService.getResolutionIndex();

    _rtmpUrlController.text = rtmpUrl ?? 'rtmps://a.rtmps.youtube.com/live2';
    _streamKeyController.text = streamKey ?? '';
    _scorecardUrlController.text = scorecardUrl ?? '';

    final bitratePreset = StreamSettingsService.bitratePresets.where((p) => p.bitrate == bitrate).firstOrNull;
    _bitrateController.text = bitratePreset?.name ?? 'High (8 Mbps)';

    if (resolutionIndex >= 0 && resolutionIndex < StreamSettingsService.resolutionPresets.length) {
      _resolutionController.text = StreamSettingsService.resolutionPresets[resolutionIndex].name;
    } else {
      _resolutionController.text = '1080p (Full HD)';
    }

    await _ytService.restoreAccount();
    _ytAccountEmail = _ytService.currentAccountEmail;

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedBitrate = StreamSettingsService.bitratePresets
        .where((p) => p.name == _bitrateController.text)
        .firstOrNull;
    final bitrate = selectedBitrate?.bitrate ?? StreamSettingsService.defaultBitrate;

    final selectedResolution = StreamSettingsService.resolutionPresets
        .asMap()
        .entries
        .where((e) => e.value.name == _resolutionController.text)
        .firstOrNull;
    final resolutionIndex = selectedResolution?.key ?? 1;

    await StreamSettingsService.saveSettings(
      _rtmpUrlController.text.trim(),
      _streamKeyController.text.trim(),
    );
    await StreamSettingsService.saveScorecardUrl(
      _scorecardUrlController.text.trim(),
    );
    await StreamSettingsService.saveBitrate(bitrate);
    await StreamSettingsService.saveResolution(resolutionIndex);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    }
  }

  Future<void> _testScorecardUrl() async {
    final url = _scorecardUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final data = await PlayCricketScraper.fetchMatchData(url);

    setState(() {
      _isTesting = false;
      if (data != null && data.homeScore.isNotEmpty) {
        _testResult =
            '✓ ${data.homeTeam} ${data.homeScore} (${data.homeOvers} ov) vs '
            '${data.awayTeam} ${data.awayScore} (${data.awayOvers} ov)';
      } else {
        _testResult = '✗ Could not parse score data from URL';
      }
    });
  }

  Future<void> _switchYtAccount() async {
    setState(() => _isLoading = true);
    final success = await _ytService.switchAccount();
    if (success) {
      _ytAccountEmail = _ytService.currentAccountEmail;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to: $_ytAccountEmail')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account switch cancelled or failed')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signOutYt() async {
    await _ytService.signOut();
    setState(() => _ytAccountEmail = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out of YouTube')),
      );
    }
  }

  @override
  void dispose() {
    _rtmpUrlController.dispose();
    _streamKeyController.dispose();
    _scorecardUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'YouTube Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_ytAccountEmail != null)
                      Text(
                        'Signed in as: $_ytAccountEmail',
                        style: const TextStyle(fontSize: 14, color: Colors.green),
                      )
                    else
                      const Text(
                        'Not signed in',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _switchYtAccount,
                          child: Text(_ytAccountEmail != null ? 'Switch Account' : 'Sign In'),
                        ),
                        if (_ytAccountEmail != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _signOutYt,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scorecard URL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _scorecardUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Play-Cricket Match URL',
                        hintText:
                            'https://yourclub.play-cricket.com/website/results/1234567',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isTesting ? null : _testScorecardUrl,
                          child: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Test URL'),
                        ),
                      ],
                    ),
                    if (_testResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testResult!.startsWith('✓')
                                ? Colors.green
                                : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'RTMP Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _rtmpUrlController,
                      decoration: const InputDecoration(
                        labelText: 'RTMP Server URL',
                        hintText: 'rtmps://a.rtmps.youtube.com/live2',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter RTMP URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _streamKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Stream Key',
                        hintText: 'Your YouTube stream key',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter stream key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _bitrateController.text.isEmpty 
                          ? 'High (8 Mbps)' 
                          : _bitrateController.text,
                      decoration: const InputDecoration(
                        labelText: 'Bitrate',
                        border: OutlineInputBorder(),
                      ),
                      items: StreamSettingsService.bitratePresets.map((preset) {
                        return DropdownMenuItem(
                          value: preset.name,
                          child: Text(preset.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _bitrateController.text = value;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _resolutionController.text.isEmpty 
                          ? '1080p (Full HD)' 
                          : _resolutionController.text,
                      decoration: const InputDecoration(
                        labelText: 'Resolution',
                        border: OutlineInputBorder(),
                      ),
                      items: StreamSettingsService.resolutionPresets.map((preset) {
                        return DropdownMenuItem(
                          value: preset.name,
                          child: Text(preset.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _resolutionController.text = value;
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
