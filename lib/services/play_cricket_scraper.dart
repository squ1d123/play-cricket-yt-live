import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class MatchData {
  final String homeTeam;
  final String homeScore;
  final String homeOvers;
  final String awayTeam;
  final String awayScore;
  final String awayOvers;
  final String result;

  const MatchData({
    this.homeTeam = '',
    this.homeScore = '',
    this.homeOvers = '',
    this.awayTeam = '',
    this.awayScore = '',
    this.awayOvers = '',
    this.result = '',
  });
}

class PlayCricketScraper {
  static Future<MatchData?> fetchMatchData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final document = html_parser.parse(response.body);

      // The match summary section contains team names and scores
      // Format on page: "Team Name 166 / 4 (16.0)"
      final scoreElements = document.querySelectorAll('.team-score-full');
      
      String homeTeam = '';
      String homeScore = '';
      String homeOvers = '';
      String awayTeam = '';
      String awayScore = '';
      String awayOvers = '';
      String result = '';

      // Try to get team names from the header section
      final teamNames = document.querySelectorAll('.team-name');
      if (teamNames.length >= 2) {
        homeTeam = teamNames[0].text.trim();
        awayTeam = teamNames[1].text.trim();
      }

      // Try to get scores - play-cricket uses various class patterns
      if (scoreElements.length >= 2) {
        final homeParsed = _parseScoreLine(scoreElements[0].text.trim());
        homeScore = homeParsed['score'] ?? '';
        homeOvers = homeParsed['overs'] ?? '';
        if (homeTeam.isEmpty) homeTeam = homeParsed['team'] ?? '';

        final awayParsed = _parseScoreLine(scoreElements[1].text.trim());
        awayScore = awayParsed['score'] ?? '';
        awayOvers = awayParsed['overs'] ?? '';
        if (awayTeam.isEmpty) awayTeam = awayParsed['team'] ?? '';
      }

      // Fallback: look for score text in common play-cricket patterns
      if (homeScore.isEmpty) {
        final allText = document.body?.text ?? '';
        final scorePattern = RegExp(r'(\d+)\s*/\s*(\d+)\s*\((\d+\.?\d*)\)');
        final matches = scorePattern.allMatches(allText).toList();
        if (matches.isNotEmpty) {
          homeScore = '${matches[0].group(1)}/${matches[0].group(2)}';
          homeOvers = matches[0].group(3) ?? '';
        }
        if (matches.length >= 2) {
          awayScore = '${matches[1].group(1)}/${matches[1].group(2)}';
          awayOvers = matches[1].group(3) ?? '';
        }
      }

      // Try to find team names from page text if still empty
      if (homeTeam.isEmpty) {
        final headerElements = document.querySelectorAll('.match-team-name, .card-header, h3, h4');
        for (final el in headerElements) {
          final text = el.text.trim();
          if (text.isNotEmpty && !text.contains('pts') && text.length < 50) {
            if (homeTeam.isEmpty) {
              homeTeam = text;
            } else if (awayTeam.isEmpty && text != homeTeam) {
              awayTeam = text;
              break;
            }
          }
        }
      }

      // Get result
      final resultElements = document.querySelectorAll('.result-text, .match-result');
      if (resultElements.isNotEmpty) {
        result = resultElements.first.text.trim();
      }
      if (result.isEmpty) {
        final wonPattern = RegExp(r'WON BY .+', caseSensitive: false);
        final bodyText = document.body?.text ?? '';
        final wonMatch = wonPattern.firstMatch(bodyText);
        if (wonMatch != null) {
          result = wonMatch.group(0) ?? '';
        }
      }

      return MatchData(
        homeTeam: homeTeam,
        homeScore: homeScore,
        homeOvers: homeOvers,
        awayTeam: awayTeam,
        awayScore: awayScore,
        awayOvers: awayOvers,
        result: result,
      );
    } catch (e) {
      return null;
    }
  }

  static Map<String, String> _parseScoreLine(String line) {
    // Parse lines like "De Beauvoir Dugongs 166 / 4 (16.0)"
    final pattern = RegExp(r'(.+?)\s*(\d+)\s*/\s*(\d+)\s*\((\d+\.?\d*)\)');
    final match = pattern.firstMatch(line);
    if (match != null) {
      return {
        'team': match.group(1)?.trim() ?? '',
        'score': '${match.group(2)}/${match.group(3)}',
        'overs': match.group(4) ?? '',
      };
    }
    return {};
  }
}
