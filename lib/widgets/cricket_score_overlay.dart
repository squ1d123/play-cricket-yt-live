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
      top: 40,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              score,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (result.isNotEmpty)
              Text(
                result,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}