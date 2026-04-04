import 'package:flutter/material.dart';

/// Color constants for the Signal puzzle game.
class SignalColors {
  SignalColors._();

  /// Empty cell background.
  static const empty = Color(0xFFF5F5F5);

  /// Wall cell fill.
  static const wall = Color(0xFF424242);

  /// Signal ray highlight extending from towers.
  static const signalRay = Color(0xFF42A5F5);

  /// Tower satisfied — signal count matches target.
  static const satisfied = Color(0xFF4CAF50);

  /// Tower conflict — signal count exceeds target.
  static const conflict = Color(0xFFE53935);

  /// Tower unsatisfied — signal count below target (default).
  static const unsatisfied = Color(0xFF757575);

  /// Tower cell background.
  static const towerBackground = Color(0xFFE3F2FD);
}
