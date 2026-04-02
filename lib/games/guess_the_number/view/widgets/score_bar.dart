import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';
import 'package:very_good_games/games/guess_the_number/theme/game_colors.dart';

/// A horizontal progress bar showing the player's remaining score budget.
///
/// Drains from right to left as time passes and questions are asked.
/// Color shifts from green → yellow → red as the score drops.
class ScoreBar extends StatelessWidget {
  /// Creates a [ScoreBar].
  const ScoreBar({
    required this.score,
    super.key,
  });

  /// The current score (0 to [ScoreCalculator.startingBudget]).
  final int score;

  @override
  Widget build(BuildContext context) {
    const budget = ScoreCalculator.startingBudget;
    final fraction = (score / budget).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _barColor(fraction),
                ),
              ),
              Text(
                '$budget',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(_barColor(fraction)),
            ),
          ),
        ],
      ),
    );
  }

  /// Green above 50%, yellow 20-50%, red below 20%.
  static Color _barColor(double fraction) {
    if (fraction > 0.5) return GameColors.scoreHigh;
    if (fraction > 0.2) return GameColors.scoreMedium;
    return GameColors.scoreLow;
  }
}
