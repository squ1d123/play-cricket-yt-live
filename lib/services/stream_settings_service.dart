import 'package:shared_preferences/shared_preferences.dart';

class StreamSettingsService {
  static const String _rtmpUrlKey = 'rtmp_url';
  static const String _streamKeyKey = 'stream_key';

  static Future<String?> getRtmpUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rtmpUrlKey);
  }

  static Future<String?> getStreamKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_streamKeyKey);
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
}
