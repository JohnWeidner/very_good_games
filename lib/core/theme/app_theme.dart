import 'package:flutter/material.dart';

/// App-wide theme configuration.
class AppTheme {
  /// The light theme for Very Good Games.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6750A4),
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
