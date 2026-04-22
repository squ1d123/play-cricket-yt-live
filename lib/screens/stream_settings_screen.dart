import 'package:flutter/material.dart';
import '../services/stream_settings_service.dart';

class StreamSettingsScreen extends StatefulWidget {
  const StreamSettingsScreen({super.key});

  @override
  State<StreamSettingsScreen> createState() => _StreamSettingsScreenState();
}

class _StreamSettingsScreenState extends State<StreamSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rtmpUrlController = TextEditingController();
  final _streamKeyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final rtmpUrl = await StreamSettingsService.getRtmpUrl();
    final streamKey = await StreamSettingsService.getStreamKey();
    
    _rtmpUrlController.text = rtmpUrl ?? 'rtmps://a.rtmps.youtube.com/live2';
    _streamKeyController.text = streamKey ?? '';
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    await StreamSettingsService.saveSettings(
      _rtmpUrlController.text.trim(),
      _streamKeyController.text.trim(),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    }
  }

  @override
  void dispose() {
    _rtmpUrlController.dispose();
    _streamKeyController.dispose();
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
                      'Configure your YouTube RTMP settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 16),
                    const Text(
                      'How to find your stream key:\n'
                      '1. Go to YouTube Studio\n'
                      '2. Click Create → Go live\n'
                      '3. Look in Stream settings',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}