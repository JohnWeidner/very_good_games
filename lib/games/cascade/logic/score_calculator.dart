import 'dart:math';

/// Returns the raw score for a completed Cascade game.
///
/// Score is attempt-based, inverted to higher-is-better:
/// 1 attempt = 100, 2 = 75, 3 = 50, 4 = 25, 5+ = 10.
int cascadeScore(int attempts) => max(100 - (attempts - 1) * 25, 10);

/// Returns the star rating (1-3) for a Cascade game.
///
/// - 3 stars: solved on first attempt
/// - 2 stars: solved in 2-3 attempts
/// - 1 star: 4 or more attempts
int cascadeStars(int attempts) {
  if (attempts == 1) return 3;
  if (attempts <= 3) return 2;
  return 1;
}
