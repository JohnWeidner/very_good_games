import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

/// Centralized color definitions for the Guess the Number game.
class GameColors {
  GameColors._();

  // Cell state colors.
  static const possible = Color(0xFF4CAF50);
  static const eliminated = Color(0xFFBDBDBD);
  static const wrongGuess = Color(0xFFE53935);
  static const target = Color(0xFFFFD600);

  // Interaction colors.
  static const highlight = Color(0xFF1565C0);
  static const selected = Color(0xFFE65100);

  // Score bar colors.
  static const scoreHigh = Color(0xFF4CAF50);
  static const scoreMedium = Color(0xFFFFA726);
  static const scoreLow = Color(0xFFE53935);

  /// Returns the color for a [CellState].
  static Color forCellState(CellState state) => switch (state) {
    CellState.possible => possible,
    CellState.eliminated => eliminated,
    CellState.wrongGuess => wrongGuess,
    CellState.target => target,
  };

  /// Returns the color for a [QuestionCategory].
  static Color forCategory(QuestionCategory category) => switch (category) {
    QuestionCategory.comparison => const Color(0xFF1565C0),
    QuestionCategory.math => const Color(0xFF7B1FA2),
    QuestionCategory.guess => const Color(0xFFE65100),
    QuestionCategory.special => const Color(0xFFC62828),
  };
}
