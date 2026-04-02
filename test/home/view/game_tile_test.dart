import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/cubit/home_cubit.dart';
import 'package:very_good_games/home/view/widgets/game_tile.dart';

class _MockGameDefinition extends Mock implements GameDefinition {}

void main() {
  group('GameTile', () {
    late GameDefinition game;

    setUp(() {
      game = _MockGameDefinition();
      when(() => game.id).thenReturn('test');
      when(() => game.name).thenReturn('Test Game');
      when(() => game.description).thenReturn('A fun test');
      when(() => game.icon).thenReturn(Icons.games);
      when(() => game.routePath).thenReturn('/games/test');
    });

    Widget buildSubject({
      DailyGameStatus dailyStatus = DailyGameStatus.notStarted,
      StreakData streak = const StreakData(),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: GameTile(
            entry: HomeGameEntry(
              definition: game,
              dailyStatus: dailyStatus,
              streak: streak,
            ),
          ),
        ),
      );
    }

    testWidgets('renders game name and description', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Test Game'), findsOneWidget);
      expect(find.text('A fun test'), findsOneWidget);
    });

    testWidgets('renders game icon', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.games), findsOneWidget);
    });

    testWidgets('shows outline circle when not started', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('shows check circle when completed', (tester) async {
      await tester.pumpWidget(
        buildSubject(dailyStatus: DailyGameStatus.completed),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('shows streak count when streak > 0', (tester) async {
      await tester.pumpWidget(
        buildSubject(streak: const StreakData(currentStreak: 5)),
      );

      expect(find.text('5 days'), findsOneWidget);
    });

    testWidgets('shows singular day for streak of 1', (tester) async {
      await tester.pumpWidget(
        buildSubject(streak: const StreakData(currentStreak: 1)),
      );

      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('hides streak count when streak is 0', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.textContaining('day'), findsNothing);
    });
  });
}
