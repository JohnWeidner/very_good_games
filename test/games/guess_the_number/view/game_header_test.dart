import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/game_header.dart';

void main() {
  group('GameHeader', () {
    GameState makeState({
      int elapsedSeconds = 0,
      int questionCount = 0,
      String? lastResult,
    }) {
      return GameState(
        cells: List.filled(400, CellState.possible),
        targetNumber: 100,
        elapsedSeconds: elapsedSeconds,
        questionCount: questionCount,
        lastResult: lastResult,
      );
    }

    testWidgets('displays timer as MM:SS', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHeader(state: makeState(elapsedSeconds: 65)),
          ),
        ),
      );
      expect(find.text('01:05'), findsOneWidget);
    });

    testWidgets('displays question count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHeader(state: makeState(questionCount: 3))),
        ),
      );
      expect(find.text('3 asked'), findsOneWidget);
    });

    testWidgets('displays remaining count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHeader(state: makeState())),
        ),
      );
      expect(find.text('400 left'), findsOneWidget);
    });

    testWidgets('displays last result when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHeader(
              state: makeState(lastResult: 'Is odd? NO — 200 eliminated'),
            ),
          ),
        ),
      );
      expect(find.text('Is odd? NO — 200 eliminated'), findsOneWidget);
    });

    testWidgets('hides last result when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHeader(state: makeState())),
        ),
      );
      // Only the stats row should be present — no result text.
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('0 asked'), findsOneWidget);
    });
  });
}
