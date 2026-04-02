/// The visual state of a single cell on the game grid.
enum CellState {
  /// Number is still a candidate (green).
  possible,

  /// Ruled out by a question (gray/dimmed).
  eliminated,

  /// Guessed with `=` and was incorrect (red).
  wrongGuess,

  /// The correct answer, revealed on win (gold).
  target,
}
