import 'dart:math';

/// Calculates the player's score for a Signal puzzle based on move count.
class SignalScoreCalculator {
  /// The starting score budget.
  static const startingBudget = 500;

  /// Points deducted per move (each wall toggle).
  static const costPerMove = 20;

  /// Returns the score for a completed game.
  ///
  /// Formula: `max(0, 500 - moveCount * 20)`
  static int calculate(int moveCount) {
    return max(0, startingBudget - moveCount * costPerMove);
  }

  /// Returns the star rating (1–3) for a given score.
  ///
  /// - 3 stars: score >= 400
  /// - 2 stars: score >= 250
  /// - 1 star: score > 0
  static int stars(int score) {
    if (score >= 400) return 3;
    if (score >= 250) return 2;
    return 1;
  }
}
