import 'package:flutter/material.dart';

/// Color constants for the Cascade game.
abstract final class CascadeColors {
  /// Ball 1 color (red).
  static const ball1 = Color(0xFFE53935);

  /// Ball 2 color (blue).
  static const ball2 = Color(0xFF1E88E5);

  /// Ball 3 color (yellow).
  static const ball3 = Color(0xFFFDD835);

  /// Lever body color.
  static const lever = Color(0xFF616161);

  /// Lever active color (during flip animation).
  static const leverActive = Color(0xFF424242);

  /// Correct bin glow color.
  static const binCorrect = Color(0xFF43A047);

  /// Neutral bin color.
  static const binNeutral = Color(0xFF9E9E9E);

  /// Board background color.
  static const board = Color(0xFFF5F5F5);

  /// Subtle grid line color.
  static const gridLine = Color(0xFFE0E0E0);
}
