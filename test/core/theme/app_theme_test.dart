import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3', () {
      final theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
    });

    test('light theme has light brightness', () {
      final theme = AppTheme.light;

      expect(theme.brightness, equals(Brightness.light));
    });

    test('light theme centers app bar title', () {
      final theme = AppTheme.light;

      expect(theme.appBarTheme.centerTitle, isTrue);
    });
  });
}
