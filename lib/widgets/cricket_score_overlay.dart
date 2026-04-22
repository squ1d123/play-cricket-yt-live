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
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = screenWidth > 500;
    
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBatsmenSection(isLandscape),
                SizedBox(width: isLandscape ? 24 : 16),
                _buildScoreSection(isLandscape),
                SizedBox(width: isLandscape ? 24 : 16),
                _buildBowlerSection(isLandscape),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatsmenSection(bool isLarge) {
    final fontSize = isLarge ? 14.0 : 12.0;
    final iconSize = isLarge ? 14.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBatsmanRow('John Smith', 45, 32, true, fontSize, iconSize),
        SizedBox(height: 2),
        _buildBatsmanRow('Mike Jones', 23, 18, false, fontSize, iconSize),
      ],
    );
  }

  Widget _buildBatsmanRow(String name, int runs, int balls, bool onStrike, double fontSize, double iconSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onStrike)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              Icons.sports_cricket,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        Text(
          name,
          style: TextStyle(
            color: onStrike ? Colors.white : Colors.white70,
            fontSize: fontSize,
            fontWeight: onStrike ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$runs ($balls)',
          style: TextStyle(
            color: onStrike ? Colors.green : Colors.green.shade300,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSection(bool isLarge) {
    final fontSize = isLarge ? 28.0 : 24.0;
    final smallFontSize = isLarge ? 14.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '166/4',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '16.4 ov',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: smallFontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildBowlerSection(bool isLarge) {
    final fontSize = isLarge ? 14.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sameer Magan',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '1/22',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '(3)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ],
    );
  }
}