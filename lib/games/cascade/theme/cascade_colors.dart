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

  /// Neutral bin color.
  static const binNeutral = Color(0xFF9E9E9E);

  /// Board background color.
  static const board = Color(0xFFF5F5F5);

  /// Subtle grid line color.
  static const gridLine = Color(0xFFE0E0E0);

  /// Drop slot edge cell background (columns 0 and 4).
  static const slotEdge = Color(0xFFD0D0D0);

  /// Drop slot center cell background (columns 1-3).
  static const slotCenter = Color(0xFFEEEEEE);
}
