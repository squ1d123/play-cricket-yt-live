import 'package:shared_preferences/shared_preferences.dart';
import 'package:rtmp_streaming/camera.dart';

class BitratePreset {
  final String name;
  final int bitrate;
  const BitratePreset(this.name, this.bitrate);
}

class ResolutionPresetOption {
  final String name;
  final ResolutionPreset preset;
  final String youtubeResolution;
  final int width;
  final int height;
  const ResolutionPresetOption(this.name, this.preset, this.youtubeResolution, this.width, this.height);
}

class StreamSettingsService {
  static const String _rtmpUrlKey = 'rtmp_url';
  static const String _streamKeyKey = 'stream_key';
  static const String _scorecardUrlKey = 'scorecard_url';
  static const String _bitrateKey = 'bitrate';
  static const String _resolutionKey = 'resolution';

  static const List<BitratePreset> bitratePresets = [
    BitratePreset('Good (6 Mbps)', 6 * 1024 * 1024),
    BitratePreset('High (8 Mbps)', 8 * 1024 * 1024),
    BitratePreset('Very High (12 Mbps)', 12 * 1024 * 1024),
    BitratePreset('Excellent (15 Mbps)', 15 * 1024 * 1024),
    BitratePreset('Ultra (20 Mbps)', 20 * 1024 * 1024),
  ];

  static const List<ResolutionPresetOption> resolutionPresets = [
    ResolutionPresetOption('720p (HD)', ResolutionPreset.high, '720p', 1280, 720),
    ResolutionPresetOption('1080p (Full HD)', ResolutionPreset.veryHigh, '1080p', 1920, 1080),
    ResolutionPresetOption('1440p (2K)', ResolutionPreset.ultraHigh, '1440p', 2560, 1440),
    ResolutionPresetOption('4K', ResolutionPreset.max, '2160p', 3840, 2160),
  ];

  static int get defaultBitrate => bitratePresets[1].bitrate;
  static ResolutionPreset get defaultResolution => resolutionPresets[1].preset;

  static Future<String?> getRtmpUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rtmpUrlKey);
  }

  static Future<String?> getStreamKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_streamKeyKey);
  }

  static Future<String?> getScorecardUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scorecardUrlKey);
  }

  static Future<void> saveScorecardUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scorecardUrlKey, url);
  }

  static Future<void> saveSettings(String rtmpUrl, String streamKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rtmpUrlKey, rtmpUrl);
    await prefs.setString(_streamKeyKey, streamKey);
  }

  static Future<String> getFullRtmpUrl() async {
    final rtmpUrl = await getRtmpUrl() ?? 'rtmps://a.rtmps.youtube.com/live2';
    final streamKey = await getStreamKey() ?? '';
    if (streamKey.isEmpty) return rtmpUrl;
    return '$rtmpUrl/$streamKey';
  }

  static Future<bool> hasSettings() async {
    final streamKey = await getStreamKey();
    return streamKey != null && streamKey.isNotEmpty;
  }

  static Future<int> getBitrate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bitrateKey) ?? defaultBitrate;
  }

  static Future<void> saveBitrate(int bitrate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bitrateKey, bitrate);
  }

  static Future<ResolutionPreset> getResolution() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_resolutionKey) ?? 1;
    if (index >= 0 && index < resolutionPresets.length) {
      return resolutionPresets[index].preset;
    }
    return defaultResolution;
  }

  static Future<String> getYoutubeResolution() async {
    final index = await getResolutionIndex();
    if (index >= 0 && index < resolutionPresets.length) {
      return resolutionPresets[index].youtubeResolution;
    }
    return '1080p';
  }

  static Future<(int, int)> getStreamDimensions() async {
    final index = await getResolutionIndex();
    if (index >= 0 && index < resolutionPresets.length) {
      return (resolutionPresets[index].width, resolutionPresets[index].height);
    }
    return (1920, 1080);
  }

  static Future<int> getResolutionIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_resolutionKey) ?? 1;
  }

  static Future<void> saveResolution(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_resolutionKey, index);
  }
}
