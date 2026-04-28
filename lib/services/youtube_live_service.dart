import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class YouTubeLiveService {
  static const _scopes = [
    'https://www.googleapis.com/auth/youtube',
    'https://www.googleapis.com/auth/youtube.force-ssl',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  GoogleSignInAccount? _account;
  yt.YouTubeApi? _api;

  bool get isSignedIn => _account != null;

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;
      final auth = await _account!.authentication;
      final client = AuthenticatedClient({
        'Authorization': 'Bearer ${auth.accessToken}',
      });
      _api = yt.YouTubeApi(client);
      return true;
    } catch (e) {
      debugPrint('YouTube sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _api = null;
  }

  /// Creates a broadcast, creates a stream, binds them, and returns the RTMP ingestion URL.
  /// Returns null on failure.
  Future<String?> createAndBindStream({
    required String title,
    String privacy = 'unlisted',
  }) async {
    if (_api == null) return null;

    try {
      // 1. Create broadcast
      final broadcast = await _api!.liveBroadcasts.insert(
        yt.LiveBroadcast(
          snippet: yt.LiveBroadcastSnippet(
            title: title,
            scheduledStartTime: DateTime.now().toUtc(),
          ),
          contentDetails: yt.LiveBroadcastContentDetails(
            enableAutoStart: true,
            enableAutoStop: true,
          ),
          status: yt.LiveBroadcastStatus(
            privacyStatus: privacy,
            selfDeclaredMadeForKids: false,
          ),
        ),
        ['snippet', 'contentDetails', 'status'],
      );

      final broadcastId = broadcast.id!;
      debugPrint('Created broadcast: $broadcastId');

      // 2. Create stream
      final stream = await _api!.liveStreams.insert(
        yt.LiveStream(
          snippet: yt.LiveStreamSnippet(title: '$title - Stream'),
          cdn: yt.CdnSettings(
            frameRate: '30fps',
            ingestionType: 'rtmp',
            resolution: '1080p',
          ),
        ),
        ['snippet', 'cdn'],
      );

      final streamId = stream.id!;
      final ingestionUrl = stream.cdn!.ingestionInfo!.ingestionAddress!;
      final streamName = stream.cdn!.ingestionInfo!.streamName!;
      debugPrint('Created stream: $streamId');

      // 3. Bind stream to broadcast
      await _api!.liveBroadcasts.bind(
        broadcastId,
        ['id', 'contentDetails'],
        streamId: streamId,
      );
      debugPrint('Bound stream $streamId to broadcast $broadcastId');

      return '$ingestionUrl/$streamName';
    } catch (e) {
      debugPrint('YouTube Live API error: $e');
      return null;
    }
  }
}
