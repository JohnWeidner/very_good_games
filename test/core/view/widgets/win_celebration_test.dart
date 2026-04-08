import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/core/core.dart';

void main() {
  group('WinCelebration', () {
    late GlobalKey<WinCelebrationState> celebrationKey;

    Widget buildSubject() {
      celebrationKey = GlobalKey<WinCelebrationState>();
      return MaterialApp(
        home: Scaffold(
          body: WinCelebration(
            key: celebrationKey,
            child: const Text('game content'),
          ),
        ),
      );
    }

    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('game content'), findsOneWidget);
    });

    testWidgets('does not show confetti initially', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('trigger shows confetti after 200ms', (tester) async {
      await tester.pumpWidget(buildSubject());

      var resultsCalled = false;
      celebrationKey.currentState!.trigger(
        onShowResults: () => resultsCalled = true,
      );

      // Before 200ms — no confetti yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ConfettiWidget), findsNothing);

      // After 200ms — confetti appears.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ConfettiWidget), findsOneWidget);
      expect(resultsCalled, isFalse);
    });

    testWidgets('trigger calls onShowResults after 1.4s total',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      var resultsCalled = false;
      celebrationKey.currentState!.trigger(
        onShowResults: () => resultsCalled = true,
      );

      // 200ms for confetti start.
      await tester.pump(const Duration(milliseconds: 200));
      expect(resultsCalled, isFalse);

      // 1200ms more for results.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(resultsCalled, isTrue);
    });

    testWidgets('reset cancels timers and hides confetti',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      var resultsCalled = false;
      celebrationKey.currentState!
        ..trigger(onShowResults: () => resultsCalled = true)
        ..reset();

      // Wait past all timers.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.byType(ConfettiWidget), findsNothing);
      expect(resultsCalled, isFalse);
    });

    testWidgets('of() returns state from ancestor', (tester) async {
      WinCelebrationState? foundState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinCelebration(
              child: Builder(
                builder: (context) {
                  foundState = WinCelebration.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(foundState, isNotNull);
    });
  });
}
