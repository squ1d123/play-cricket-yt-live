import 'package:flutter/material.dart';

class CricketScoreOverlay extends StatelessWidget {
  final String teamName;
  final String score;
  final String result;

  const CricketScoreOverlay({
    super.key,
    required this.teamName,
    required this.score,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBatsmenSection(),
              const SizedBox(width: 24),
              _buildScoreSection(),
              const SizedBox(width: 24),
              _buildBowlerSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatsmenSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBatsmanRow('John Smith', 45, 32, true),
        const SizedBox(height: 4),
        _buildBatsmanRow('Mike Jones', 23, 18, false),
      ],
    );
  }

  Widget _buildBatsmanRow(String name, int runs, int balls, bool onStrike) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onStrike)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              Icons.sports_cricket,
              color: Colors.white,
              size: 14,
            ),
          ),
        Text(
          name,
          style: TextStyle(
            color: onStrike ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: onStrike ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 8),
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

  Widget _buildScoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Text(
          '16.4 ov',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBowlerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sameer Magan',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '1/22',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(3)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}