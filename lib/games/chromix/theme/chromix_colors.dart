import 'package:flutter/material.dart';

/// Color constants for the Chromix game.
abstract final class ChromixColors {
  /// Red primary.
  static const red = Color(0xFFE53935);

  /// Yellow primary.
  static const yellow = Color(0xFFFDD835);

  /// Blue primary.
  static const blue = Color(0xFF1E88E5);

  /// Orange secondary (red + yellow).
  static const orange = Color(0xFFFB8C00);

  /// Green secondary (yellow + blue).
  static const green = Color(0xFF43A047);

  /// Purple secondary (red + blue).
  static const purple = Color(0xFF8E24AA);

  /// Black blocker cell.
  static const blocker = Color(0xFF212121);

  /// Light gray empty cell.
  static const empty = Color(0xFFE0E0E0);

  /// Highlight ring for selected color.
  static const selectedRing = Color(0xFF424242);
}
