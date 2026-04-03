import 'dart:math';

/// Calculates the player's score based on questions asked and time elapsed.
class ScoreCalculator {
  /// The starting score budget. Controls max game length.
  ///
  /// At 600: ~5 min max time, ~12 questions max.
  static const startingBudget = 600;

  /// Points deducted per question asked.
  static const costPerQuestion = 50;

  /// Points deducted per second elapsed.
  static const costPerSecond = 2;

  /// Returns the score for a completed game.
  ///
  /// Formula: `max(0, 600 - (questions * 50) - (seconds * 2))`
  static int calculate({required int questions, required int seconds}) {
    return max(
      0,
      startingBudget -
          (questions * costPerQuestion) -
          (seconds * costPerSecond),
    );
  }

  /// Returns the star rating (1–3) for a given score.
  ///
  /// - 3 stars: score >= 450
  /// - 2 stars: score >= 250
  /// - 1 star: everything else
  static int stars(int score) {
    if (score >= 450) return 3;
    if (score >= 250) return 2;
    return 1;
  }
}
