import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/settings/settings.dart';

extension on WidgetTester {
  Future<void> pumpSettingsPage() {
    return pumpWidget(const MaterialApp(home: SettingsPage()));
  }
}

void main() {
  group('SettingsPage', () {
    testWidgets('renders Settings title in AppBar', (tester) async {
      await tester.pumpSettingsPage();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Nostr Identity ListTile', (tester) async {
      await tester.pumpSettingsPage();

      expect(find.text('Nostr Identity'), findsOneWidget);
      expect(find.text('Set up your identity'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
