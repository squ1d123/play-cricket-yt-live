import 'package:flutter/material.dart';

class CricketScoreOverlay extends StatelessWidget {
  final String teamName;
  final String score;
  final String overs;
  final String batsman1Name;
  final int batsman1Runs;
  final int batsman1Balls;
  final bool batsman1OnStrike;
  final String batsman2Name;
  final int batsman2Runs;
  final int batsman2Balls;
  final String bowlerName;
  final int bowlerWickets;
  final int bowlerRuns;
  final int bowlerOvers;

  const CricketScoreOverlay({
    super.key,
    required this.teamName,
    required this.score,
    this.overs = '',
    this.batsman1Name = '',
    this.batsman1Runs = 0,
    this.batsman1Balls = 0,
    this.batsman1OnStrike = true,
    this.batsman2Name = '',
    this.batsman2Runs = 0,
    this.batsman2Balls = 0,
    this.bowlerName = '',
    this.bowlerWickets = 0,
    this.bowlerRuns = 0,
    this.bowlerOvers = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          // Batsmen section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBatsmanRow(batsman1Name, batsman1Runs, batsman1Balls, batsman1OnStrike),
                const SizedBox(height: 2),
                _buildBatsmanRow(batsman2Name, batsman2Runs, batsman2Balls, !batsman1OnStrike),
              ],
            ),
          ),
          // Score section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (overs.isNotEmpty)
                  Text(
                    '$overs ov',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          // Bowler section
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bowlerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$bowlerWickets/$bowlerRuns',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '($bowlerOvers)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmanRow(String name, int runs, int balls, bool onStrike) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onStrike)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Icon(Icons.sports_cricket, color: Colors.white, size: 14),
          ),
        Text(
          name,
          style: TextStyle(
            color: onStrike ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: onStrike ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$runs ($balls)',
          style: TextStyle(
            color: onStrike ? Colors.green : Colors.green.shade300,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
