import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/results_overlay.dart';

void main() {
  group('ResultsOverlay', () {
    Widget buildSubject(GameState state) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: ResultsOverlay(state: state)),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('shows "You found it!" on win', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          GameState(
            cells: List.filled(400, CellState.possible),
            targetNumber: 42,
            status: GameStatus.won,
            score: 350,
            questionCount: 5,
            elapsedSeconds: 30,
          ),
        ),
      );
      expect(find.text('You found it!'), findsOneWidget);
      expect(find.text('The number was 42'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    testWidgets('shows score breakdown on win', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          GameState(
            cells: List.filled(400, CellState.possible),
            targetNumber: 42,
            status: GameStatus.won,
            score: 290,
            questionCount: 5,
            elapsedSeconds: 30,
          ),
        ),
      );
      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('-250'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('-60'), findsOneWidget);
    });

    testWidgets('shows star rating on win', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          GameState(
            cells: List.filled(400, CellState.possible),
            targetNumber: 42,
            status: GameStatus.won,
            score: 500,
          ),
        ),
      );
      // 500 >= 450 → 3 stars.
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('shows "Time\'s up!" on loss', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          GameState(
            cells: List.filled(400, CellState.possible),
            targetNumber: 42,
            status: GameStatus.lost,
            score: 0,
            questionCount: 12,
            elapsedSeconds: 300,
          ),
        ),
      );
      expect(find.text("Time's up!"), findsOneWidget);
      expect(find.text('The number was 42'), findsOneWidget);
      expect(find.text('Score reached zero'), findsOneWidget);
    });

    testWidgets('shows Back to Hub button', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          GameState(
            cells: List.filled(400, CellState.possible),
            targetNumber: 42,
            status: GameStatus.won,
            score: 100,
          ),
        ),
      );
      expect(find.text('Back to Hub'), findsOneWidget);
    });
  });
}
