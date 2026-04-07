/// Returns the raw score for a completed Chromix game.
///
/// Score equals total actions taken: placements plus undos.
int chromixScore(int moves, int undos) => moves + undos;

/// Returns the star rating (1–3) for a Chromix game.
///
/// - 3 stars: score ≤ optimal moves
/// - 2 stars: score ≤ optimal + 3
/// - 1 star: anything else
int chromixStars(int score, int optimalMoves) {
  if (score <= optimalMoves) return 3;
  if (score <= optimalMoves + 3) return 2;
  return 1;
}
