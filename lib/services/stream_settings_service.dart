import 'package:shared_preferences/shared_preferences.dart';

class BitratePreset {
  final String name;
  final int bitrate;
  const BitratePreset(this.name, this.bitrate);
}

class StreamSettingsService {
  static const String _rtmpUrlKey = 'rtmp_url';
  static const String _streamKeyKey = 'stream_key';
  static const String _scorecardUrlKey = 'scorecard_url';
  static const String _bitrateKey = 'bitrate';

  static const List<BitratePreset> presets = [
    BitratePreset('Good (6 Mbps)', 6 * 1024 * 1024),
    BitratePreset('High (8 Mbps)', 8 * 1024 * 1024),
    BitratePreset('Very High (12 Mbps)', 12 * 1024 * 1024),
    BitratePreset('Excellent (15 Mbps)', 15 * 1024 * 1024),
    BitratePreset('Ultra (20 Mbps)', 20 * 1024 * 1024),
  ];

  static int get defaultBitrate => presets[2].bitrate;

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
}
