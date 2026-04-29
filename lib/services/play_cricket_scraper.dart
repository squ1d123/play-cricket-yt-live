import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

class MatchData {
  final String homeTeam;
  final String homeScore;
  final String homeOvers;
  final String awayTeam;
  final String awayScore;
  final String awayOvers;
  final String result;
  final List<BatsmanData> batsmen;
  final List<BowlerData> bowlers;

  const MatchData({
    this.homeTeam = '',
    this.homeScore = '',
    this.homeOvers = '',
    this.awayTeam = '',
    this.awayScore = '',
    this.awayOvers = '',
    this.result = '',
    this.batsmen = const [],
    this.bowlers = const [],
  });
}

class BatsmanData {
  final String name;
  final int runs;
  final int balls;
  final bool notOut;

  const BatsmanData({
    required this.name,
    required this.runs,
    required this.balls,
    this.notOut = false,
  });
}

class BowlerData {
  final String name;
  final int wickets;
  final int runs;
  final int overs;

  const BowlerData({
    required this.name,
    required this.wickets,
    required this.runs,
    required this.overs,
  });
}

class PlayCricketScraper {
  static const _apiBase = 'https://api.resultsvault.co.uk/rv/';
  static const _apiId = '1003';
  static const _sharedSecret = '5BD4A72CE1934BA5A629CD98';
  static const _masterEntityId = '130000';

  static String _generateToken() {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60).toString();
    final des = DES(key: _sharedSecret.substring(0, 8).codeUnits, mode: DESMode.ECB);
    final encrypted = des.encrypt(timestamp.codeUnits);
    return base64Encode(encrypted);
  }

  static Map<String, String> get _headers => {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'origin': 'https://play-cricket.com',
        'referer': 'https://play-cricket.com/',
        'x-ias-api-request': _generateToken(),
      };

  /// Extract the play-cricket match ID from a URL
  static int? extractMatchId(String url) {
    final match = RegExp(r'/results/(\d+)').firstMatch(url);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Map play-cricket external match ID to ResultsVault internal match ID
  static Future<int?> _getResultsVaultMatchId(int externalMatchId) async {
    final url = Uri.parse(
        '${_apiBase}mappings/4/12/$externalMatchId/?apiid=$_apiId&sportid=1');

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return data['object_id1'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Fetch full match data from the ResultsVault API
  static Future<MatchData?> fetchMatchData(String playCricketUrl) async {
    final externalId = extractMatchId(playCricketUrl);
    if (externalId == null) return null;

    final rvMatchId = await _getResultsVaultMatchId(externalId);
    if (rvMatchId == null) return null;

    final url = Uri.parse(
        '$_apiBase$_masterEntityId/matches/$rvMatchId/?apiid=$_apiId&strmflg=3');

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseMatchData(data);
    } catch (_) {
      return null;
    }
  }

  static MatchData _parseMatchData(Map<String, dynamic> data) {
    final teams = data['MatchTeams'] as List? ?? [];
    if (teams.isEmpty) {
      return MatchData(
        homeTeam: (data['home_name'] ?? '') as String,
        awayTeam: (data['away_name'] ?? '') as String,
        result: (data['leader_text'] ?? '') as String,
      );
    }

    final homeTeam = teams.firstWhere(
      (t) => t['is_home'] == true,
      orElse: () => teams[0],
    );
    final awayTeam = teams.firstWhere(
      (t) => t['is_home'] == false,
      orElse: () => teams.length > 1 ? teams[1] : teams[0],
    );

    final homeInnings = _parseInnings(homeTeam as Map<String, dynamic>);
    final awayInnings = _parseInnings(awayTeam as Map<String, dynamic>);

    // Get batsmen from the team that batted second (currently batting in a live game)
    final battingTeam =
        (homeTeam['batted_first'] == false) ? homeTeam : awayTeam;
    final bowlingTeam =
        (homeTeam['batted_first'] == false) ? awayTeam : homeTeam;

    final batsmen =
        _parseBatsmen((battingTeam as Map<String, dynamic>)['Innings'] as List?);
    final bowlers =
        _parseBowlers((bowlingTeam as Map<String, dynamic>)['Innings'] as List?);

    return MatchData(
      homeTeam: (homeTeam['club_name'] ?? '') as String,
      homeScore: homeInnings['score']!,
      homeOvers: homeInnings['overs']!,
      awayTeam: (awayTeam['club_name'] ?? '') as String,
      awayScore: awayInnings['score']!,
      awayOvers: awayInnings['overs']!,
      result: (data['leader_text'] ?? '') as String,
      batsmen: batsmen,
      bowlers: bowlers,
    );
  }

  static Map<String, String> _parseInnings(Map<String, dynamic> team) {
    final innings = team['Innings'] as List?;
    if (innings == null || innings.isEmpty) {
      final scoreText = (team['match_score_text'] ?? '') as String;
      final match = RegExp(r'(\d+)/(\d+)').firstMatch(scoreText);
      if (match != null) {
        return {'score': '${match.group(2)}/${match.group(1)}', 'overs': ''};
      }
      return {'score': '', 'overs': ''};
    }

    final inn = innings.last as Map<String, dynamic>;
    final runs = inn['runs'] ?? 0;
    final wickets = inn['wickets'] ?? 0;
    final overs = inn['overs_bowled']?.toString() ?? '';
    return {'score': '$runs/$wickets', 'overs': overs};
  }

  static List<BatsmanData> _parseBatsmen(List? innings) {
    if (innings == null || innings.isEmpty) return [];
    final perfs =
        (innings.last as Map<String, dynamic>)['PlayerPerfs'] as List? ?? [];
    return perfs
        .where((p) =>
            p['__type'] == 'Batting:http://api.resultsvault.com' &&
            p['dismissal_text'] != 'dnb' &&
            p['runs'] != null)
        .map((p) => BatsmanData(
              name: (p['player_name'] ?? '') as String,
              runs: (p['runs'] ?? 0) as int,
              balls: (p['balls'] ?? 0) as int,
              notOut: p['dismissal_text'] == 'no' ||
                  p['dismissal_text'] == 'rtno',
            ))
        .toList();
  }

  static List<BowlerData> _parseBowlers(List? innings) {
    if (innings == null || innings.isEmpty) return [];
    final perfs =
        (innings.last as Map<String, dynamic>)['PlayerPerfs'] as List? ?? [];
    return perfs
        .where((p) => p['__type'] == 'Bowling:http://api.resultsvault.com')
        .map((p) => BowlerData(
              name: (p['player_name'] ?? '') as String,
              wickets: (p['wickets'] ?? 0) as int,
              runs: (p['runs'] ?? 0) as int,
              overs: (p['overs'] ?? 0) as int,
            ))
        .toList();
  }
}
