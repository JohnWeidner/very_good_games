import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/question_card.dart';

void main() {
  group('QuestionCard', () {
    GameState makeState({
      QuestionType? activeType,
      GameStatus status = GameStatus.selectingParam,
      int? firstParam,
    }) {
      return GameState(
        cells: List.filled(400, CellState.possible),
        targetNumber: 100,
        status: status,
        activeQuestionType: activeType,
        firstParam: firstParam,
      );
    }

    testWidgets('renders nothing when activeQuestionType is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(),
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('displays question label and description',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(activeType: QuestionType.lessThan),
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.text('< N'), findsOneWidget);
      expect(find.text('Less than'), findsOneWidget);
    });

    testWidgets('shows Play and Cancel buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(activeType: QuestionType.lessThan),
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Play button disabled when not readyToConfirm',
        (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(activeType: QuestionType.lessThan),
              onConfirm: () => confirmed = true,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Play'));
      expect(confirmed, isFalse);
    });

    testWidgets('Play button enabled when readyToConfirm',
        (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(
                activeType: QuestionType.lessThan,
                status: GameStatus.readyToConfirm,
                firstParam: 200,
              ),
              onConfirm: () => confirmed = true,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Play'));
      expect(confirmed, isTrue);
    });

    testWidgets('Cancel button calls onCancel', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(activeType: QuestionType.lessThan),
              onConfirm: () {},
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('shows instruction text for no-param question',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(
                activeType: QuestionType.isOdd,
                status: GameStatus.readyToConfirm,
              ),
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(
        find.text('Tap Play to ask this question'),
        findsOneWidget,
      );
    });

    testWidgets('shows digit picker for onesDigitIs', (tester) async {
      int? digitSelected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(
                activeType: QuestionType.onesDigitIs,
              ),
              onConfirm: () {},
              onCancel: () {},
              onDigitSelected: (d) => digitSelected = d,
            ),
          ),
        ),
      );
      // Should show digit buttons 0-9.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);

      await tester.tap(find.text('5'));
      expect(digitSelected, equals(5));
    });

    testWidgets('shows grid instruction for param question',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              state: makeState(
                activeType: QuestionType.lessThan,
              ),
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(
        find.text('Slide on the grid to pick a number'),
        findsOneWidget,
      );
    });
  });
}
