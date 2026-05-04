import 'package:flutter/material.dart';
import 'screens/streaming_screen.dart';
import 'screens/stream_settings_screen.dart';
import 'services/stream_settings_service.dart';

void main() {
  runApp(const PlayCricketLiveApp());
}

class PlayCricketLiveApp extends StatelessWidget {
  const PlayCricketLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play Cricket Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasSettings = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    final hasSettings = await StreamSettingsService.hasSettings();
    setState(() {
      _hasSettings = hasSettings;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Cricket Live'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_cricket,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'De Beauvoir Dugongs Live',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasSettings ? 'Ready to stream' : 'Configure stream settings',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StreamingScreen(),
                    ),
                  );
                  await _checkSettings();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('START STREAMING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StreamSettingsScreen(),
                    ),
                  );
                  await _checkSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('SETTINGS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}