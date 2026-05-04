import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_cricket_yt_live/services/play_cricket_scraper.dart';

void main() {
  group('PlayCricketScraper', () {
    test('extractMatchId extracts ID from play-cricket URL', () {
      final url = 'https://debeauvoirdugongs.play-cricket.com/website/results/7080352';
      final matchId = PlayCricketScraper.extractMatchId(url);
      expect(matchId, 7080352);
    });

    test('extractMatchId returns null for invalid URL', () {
      final url = 'https://example.com/not-a-match';
      final matchId = PlayCricketScraper.extractMatchId(url);
      expect(matchId, null);
    });

    test('extractMatchId returns null for URL without ID', () {
      final url = 'https://debeauvoirdugongs.play-cricket.com/website/results/';
      final matchId = PlayCricketScraper.extractMatchId(url);
      expect(matchId, null);
    });

    test('MatchData has correct fields', () {
      final matchData = MatchData(
        homeTeam: 'Home Team',
        homeScore: '100/2',
        homeOvers: '10',
        awayTeam: 'Away Team',
        awayScore: '150/1',
        awayOvers: '15',
        result: 'Away won',
        battingTeam: 'Away Team',
        battingScore: '150/1',
        battingOvers: '15',
        bowlingTeam: 'Home Team',
        bowlingInningsNumber: 1,
        batsmen: [
          const BatsmanData(name: 'Player 1', runs: 50, balls: 30),
          const BatsmanData(name: 'Player 2', runs: 25, balls: 20),
        ],
        bowlers: [
          const BowlerData(bowlerId: 11959191, name: 'Bowler 1', wickets: 1, runs: 30, overs: 4),
        ],
      );

      expect(matchData.homeTeam, 'Home Team');
      expect(matchData.awayTeam, 'Away Team');
      expect(matchData.battingTeam, 'Away Team');
      expect(matchData.bowlingTeam, 'Home Team');
      expect(matchData.bowlingInningsNumber, 1);
      expect(matchData.batsmen.length, 2);
      expect(matchData.bowlers.length, 1);
    });

    test('BatsmanData has correct fields', () {
      const batsman = BatsmanData(
        name: 'John Doe',
        runs: 42,
        balls: 30,
        notOut: true,
      );

      expect(batsman.name, 'John Doe');
      expect(batsman.runs, 42);
      expect(batsman.balls, 30);
      expect(batsman.notOut, true);
    });

    test('BowlerData has correct fields', () {
      const bowler = BowlerData(
        bowlerId: 11959191,
        name: 'Jane Smith',
        wickets: 3,
        runs: 25,
        overs: 4,
      );

      expect(bowler.bowlerId, 11959191);
      expect(bowler.name, 'Jane Smith');
      expect(bowler.wickets, 3);
      expect(bowler.runs, 25);
      expect(bowler.overs, 4);
    });

    test('MatchData default values', () {
      const matchData = MatchData();

      expect(matchData.homeTeam, '');
      expect(matchData.homeScore, '');
      expect(matchData.homeOvers, '');
      expect(matchData.awayTeam, '');
      expect(matchData.awayScore, '');
      expect(matchData.awayOvers, '');
      expect(matchData.result, '');
      expect(matchData.battingTeam, '');
      expect(matchData.battingScore, '');
      expect(matchData.battingOvers, '');
      expect(matchData.bowlingTeam, '');
      expect(matchData.bowlingInningsNumber, 0);
      expect(matchData.batsmen, isEmpty);
      expect(matchData.bowlers, isEmpty);
    });

    test('fetchMatchData returns null for invalid URL', () async {
      final result = await PlayCricketScraper.fetchMatchData('invalid-url');
      expect(result, null);
    });

    test('fetchMatchData returns null for URL without match ID', () async {
      final result = await PlayCricketScraper.fetchMatchData('https://play-cricket.com/');
      expect(result, null);
    });

    test('parseCurrentBowlerFromBallData returns bowler with correct ID', () {
      final ballData = {
        'BallbyBall': [
          {'over': 1, 'ball': 1, 'bowler': 'John Doe', 'bowler_id': 11959191, 'runs': 0, 'wicket': 0},
        ]
      };

      final bowler = PlayCricketScraper.parseCurrentBowlerFromBallData(ballData);

      expect(bowler, isNotNull);
      expect(bowler!.bowlerId, 11959191);
      expect(bowler.name, 'John Doe');
    });

    test('parseCurrentBowlerFromBallData returns null for empty balls', () {
      final ballData = {'BallbyBall': <Map<String, dynamic>>[]};

      final bowler = PlayCricketScraper.parseCurrentBowlerFromBallData(ballData);

      expect(bowler, isNull);
    });

    test('fetchCurrentBowler returns bowler with expected ID from real API: 7080352', () async {
      const url = 'https://debeauvoirdugongs.play-cricket.com/website/results/7080352';
      final matchData = await PlayCricketScraper.fetchMatchData(url);
      final bowler = await PlayCricketScraper.fetchCurrentBowlerFromMatchData(matchData);

      expect(bowler, isNotNull);
      expect(bowler!.bowlerId, 11959191);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('fetchCurrentBowler returns bowler with expected ID from real API: 7080346', () async {
      const url = 'https://debeauvoirdugongs.play-cricket.com/website/results/7080346';
      final matchData = await PlayCricketScraper.fetchMatchData(url);
      final bowler = await PlayCricketScraper.fetchCurrentBowlerFromMatchData(matchData);

      expect(bowler, isNotNull);
      expect(bowler!.bowlerId, 11382051);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('fetchCurrentBowler returns bowler with expected ID from real API: 7121431', () async {
      const url = 'https://debeauvoirdugongs.play-cricket.com/website/results/7121431';
      final matchData = await PlayCricketScraper.fetchMatchData(url);
      final bowler = await PlayCricketScraper.fetchCurrentBowlerFromMatchData(matchData);

      expect(bowler, isNotNull);
      expect(bowler!.bowlerId, 12149347);
      expect(bowler.name, "C Birchall");
      expect(bowler.overs, 3);
      expect(bowler.runs, 27);
      expect(bowler.wickets, 1);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
