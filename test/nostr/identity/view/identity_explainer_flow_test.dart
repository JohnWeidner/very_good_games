import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/nostr/identity/view/identity_explainer_flow.dart';

void main() {
  group('IdentityExplainerFlow', () {
    testWidgets('renders first page with What is Nostr title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IdentityExplainerFlow()));

      expect(find.text('What is Nostr?'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('renders About Nostr in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IdentityExplainerFlow()));

      expect(find.text('About Nostr'), findsOneWidget);
    });

    testWidgets('navigates through all 5 pages', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IdentityExplainerFlow()));

      // Page 1.
      expect(find.text('What is Nostr?'), findsOneWidget);

      // Page 2.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('You Own Your Identity'), findsOneWidget);

      // Page 3.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Digital Signatures'), findsOneWidget);

      // Page 4.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Public vs. Private'), findsOneWidget);

      // Page 5.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('One ID or Many \u2014 You Decide.'), findsOneWidget);
      expect(find.text('Set Up Identity'), findsOneWidget);
    });

    testWidgets('pops with true when Set Up Identity is tapped', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const IdentityExplainerFlow(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Navigate to the last page (page 5).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Set Up Identity'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('back button dismisses without result', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const IdentityExplainerFlow(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap back button.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Skip button renders on first page', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IdentityExplainerFlow()));

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('tapping Skip pops with true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const IdentityExplainerFlow(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
