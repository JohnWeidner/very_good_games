import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

void main() {
  group('GameCubit', () {
    const target = 200;
    const targetIndex = target - 1;
    const wrongNumber = 50;
    const wrongIndex = wrongNumber - 1;

    late GameCubit cubit;

    setUp(() {
      cubit = GameCubit(targetNumber: target);
    });

    tearDown(() => cubit.close());

    test('initial state has 400 possible cells', () {
      expect(cubit.state.cells, hasLength(400));
      expect(cubit.state.cells.every((c) => c == CellState.possible), isTrue);
      expect(cubit.state.status, equals(GameStatus.playing));
      expect(cubit.state.questionCount, equals(0));
      expect(cubit.state.elapsedSeconds, equals(0));
      expect(cubit.state.highlightedCell, isNull);
      expect(cubit.state.activeQuestionType, isNull);
      expect(cubit.state.score, isNull);
      expect(cubit.state.remainingCount, equals(400));
    });

    group('selectQuestion', () {
      blocTest<GameCubit, GameState>(
        'stages a parameterized question in selectingParam',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) => cubit.selectQuestion(QuestionType.lessThan),
        expect: () => [
          isA<GameState>()
              .having((s) => s.status, 'status', GameStatus.selectingParam)
              .having(
                (s) => s.activeQuestionType,
                'activeQuestionType',
                QuestionType.lessThan,
              ),
        ],
      );

      blocTest<GameCubit, GameState>(
        'stages a no-param question in readyToConfirm',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) => cubit.selectQuestion(QuestionType.isOdd),
        expect: () => [
          isA<GameState>()
              .having((s) => s.status, 'status', GameStatus.readyToConfirm)
              .having(
                (s) => s.activeQuestionType,
                'activeQuestionType',
                QuestionType.isOdd,
              ),
        ],
      );

      blocTest<GameCubit, GameState>(
        'ignores already-used question types',
        build: () => GameCubit(targetNumber: target),
        seed: () => GameState(
          cells: List.filled(400, CellState.possible),
          targetNumber: target,
          usedQuestionTypes: const {QuestionType.isOdd},
        ),
        act: (cubit) => cubit.selectQuestion(QuestionType.isOdd),
        expect: () => <GameState>[],
      );
    });

    group('cancelQuestion', () {
      blocTest<GameCubit, GameState>(
        'returns to playing and clears staged question',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.lessThan)
            ..cancelQuestion();
        },
        expect: () => [
          isA<GameState>().having(
            (s) => s.status,
            'status',
            GameStatus.selectingParam,
          ),
          isA<GameState>()
              .having((s) => s.status, 'status', GameStatus.playing)
              .having(
                (s) => s.activeQuestionType,
                'activeQuestionType',
                isNull,
              ),
        ],
      );
    });

    group('highlightCell', () {
      blocTest<GameCubit, GameState>(
        'updates highlightedCell',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) => cubit.highlightCell(42),
        expect: () => [
          isA<GameState>().having(
            (s) => s.highlightedCell,
            'highlightedCell',
            42,
          ),
        ],
      );

      blocTest<GameCubit, GameState>(
        'clears highlight with null',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..highlightCell(42)
            ..highlightCell(null);
        },
        expect: () => [
          isA<GameState>().having(
            (s) => s.highlightedCell,
            'highlightedCell',
            42,
          ),
          isA<GameState>().having(
            (s) => s.highlightedCell,
            'highlightedCell',
            isNull,
          ),
        ],
      );
    });

    group('lockParam', () {
      blocTest<GameCubit, GameState>(
        'locks single param and transitions to readyToConfirm',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.lessThan)
            ..highlightCell(99)
            ..lockParam();
        },
        expect: () => [
          isA<GameState>().having(
            (s) => s.status,
            'status',
            GameStatus.selectingParam,
          ),
          isA<GameState>().having(
            (s) => s.highlightedCell,
            'highlightedCell',
            99,
          ),
          isA<GameState>()
              .having((s) => s.status, 'status', GameStatus.readyToConfirm)
              .having(
                (s) => s.firstParam,
                'firstParam',
                100, // 0-based index 99 = number 100
              ),
        ],
      );

      blocTest<GameCubit, GameState>(
        'does nothing when no cell is highlighted',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.lessThan)
            ..lockParam(); // no highlight
        },
        expect: () => [
          isA<GameState>().having(
            (s) => s.status,
            'status',
            GameStatus.selectingParam,
          ),
          // no second emission
        ],
      );
    });

    group('confirmQuestion', () {
      blocTest<GameCubit, GameState>(
        'applies no-param question and returns to playing',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.isOdd)
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.playing));
          expect(cubit.state.questionCount, equals(1));
          expect(cubit.state.usedQuestionTypes, contains(QuestionType.isOdd));
          expect(cubit.state.lastResult, isNotNull);
          // Target 200 is even, so "Is odd? NO" — odd numbers eliminated.
          expect(cubit.state.remainingCount, lessThan(400));
        },
      );

      blocTest<GameCubit, GameState>(
        'applies lessThan and eliminates correct cells',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.lessThan)
            ..highlightCell(249) // number 250
            ..lockParam()
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.playing));
          expect(cubit.state.questionCount, equals(1));
          // Target 200 < 250 is true, so numbers >= 250 eliminated.
          expect(cubit.state.lastResult, contains('YES'));
        },
      );

      blocTest<GameCubit, GameState>(
        'correct equals guess wins the game',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(targetIndex)
            ..lockParam()
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.won));
          expect(cubit.state.score, isNotNull);
          expect(cubit.state.cells[targetIndex], CellState.target);
          expect(cubit.state.lastResult, contains('YES'));
        },
      );

      blocTest<GameCubit, GameState>(
        'wrong equals guess marks cell red and continues',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(wrongIndex)
            ..lockParam()
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.playing));
          expect(cubit.state.cells[wrongIndex], CellState.wrongGuess);
          expect(cubit.state.lastResult, contains('too low'));
        },
      );

      blocTest<GameCubit, GameState>(
        'equals is repeatable and not added to usedTypes',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(wrongIndex)
            ..lockParam()
            ..confirmQuestion()
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(wrongIndex + 1)
            ..lockParam()
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.questionCount, equals(2));
          expect(
            cubit.state.usedQuestionTypes,
            isNot(contains(QuestionType.equals)),
          );
        },
      );

      blocTest<GameCubit, GameState>(
        'non-repeatable question is added to usedTypes',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.isOdd)
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.usedQuestionTypes, contains(QuestionType.isOdd));
        },
      );

      blocTest<GameCubit, GameState>(
        'onesDigitIs works via setDigitParam',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.onesDigitIs)
            ..setDigitParam(5) // "Ends in 5?" Target 200 ends in 0 → NO
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.playing));
          expect(cubit.state.questionCount, equals(1));
          expect(cubit.state.lastResult, contains('NO'));
        },
      );

      blocTest<GameCubit, GameState>(
        'setDigitParam sets param and transitions to readyToConfirm',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.onesDigitIs)
            ..setDigitParam(7);
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.readyToConfirm));
          expect(cubit.state.firstParam, equals(7));
        },
      );

      blocTest<GameCubit, GameState>(
        'wins when elimination leaves only one cell remaining',
        build: () => GameCubit(targetNumber: target),
        seed: () {
          // Start with only 2 possible cells: target and one other.
          final cells = List.filled(400, CellState.eliminated);
          cells[targetIndex] = CellState.possible;
          cells[0] = CellState.possible; // number 1
          return GameState(cells: cells, targetNumber: target);
        },
        act: (cubit) {
          // Use < 2 to eliminate number 1, leaving only target.
          cubit
            ..selectQuestion(QuestionType.lessThan)
            ..highlightCell(1) // number 2
            ..lockParam()
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.won));
          expect(cubit.state.score, isNotNull);
          expect(cubit.state.cells[targetIndex], CellState.target);
        },
      );

      blocTest<GameCubit, GameState>(
        'shotgun eliminates cells with injectable random',
        build: () => GameCubit(targetNumber: target, random: Random(42)),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.shotgun)
            ..confirmQuestion();
        },
        verify: (cubit) {
          expect(cubit.state.questionCount, equals(1));
          // Some cells eliminated, target still possible.
          expect(cubit.state.remainingCount, lessThan(400));
          expect(cubit.state.cells[targetIndex], CellState.possible);
        },
      );
    });

    group('tick', () {
      blocTest<GameCubit, GameState>(
        'is a no-op before timer has started',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) => cubit.tick(),
        expect: () => <GameState>[],
      );

      blocTest<GameCubit, GameState>(
        'increments elapsed seconds after timer started',
        build: () => GameCubit(targetNumber: target),
        seed: () => GameState(
          cells: List.filled(400, CellState.possible),
          targetNumber: target,
          timerStarted: true,
        ),
        act: (cubit) {
          cubit
            ..tick()
            ..tick()
            ..tick();
        },
        expect: () => [
          isA<GameState>().having((s) => s.elapsedSeconds, 'elapsedSeconds', 1),
          isA<GameState>().having((s) => s.elapsedSeconds, 'elapsedSeconds', 2),
          isA<GameState>().having((s) => s.elapsedSeconds, 'elapsedSeconds', 3),
        ],
      );

      blocTest<GameCubit, GameState>(
        'is a no-op after winning',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(targetIndex)
            ..lockParam()
            ..confirmQuestion()
            ..tick();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.won));
          expect(cubit.state.elapsedSeconds, equals(0));
        },
      );

      blocTest<GameCubit, GameState>(
        'triggers lost when score reaches zero via tick',
        build: () => GameCubit(targetNumber: target),
        seed: () => GameState(
          cells: List.filled(400, CellState.possible),
          targetNumber: target,
          timerStarted: true,
          // 11 questions already = 550 cost, leaving 50 budget.
          // 25 seconds of time = 50 cost → score = 0.
          questionCount: 11,
          elapsedSeconds: 24,
        ),
        act: (cubit) => cubit.tick(),
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.lost));
          expect(cubit.state.score, equals(0));
        },
      );

      blocTest<GameCubit, GameState>(
        'triggers lost when question cost pushes score to zero',
        build: () => GameCubit(targetNumber: target),
        seed: () => GameState(
          cells: List.filled(400, CellState.possible),
          targetNumber: target,
          timerStarted: true,
          questionCount: 11, // 550 spent, 50 left
        ),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.isOdd)
            ..confirmQuestion(); // costs 50 → score = 0
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.lost));
          expect(cubit.state.score, equals(0));
        },
      );
    });

    group('post-win guards', () {
      blocTest<GameCubit, GameState>(
        'selectQuestion is a no-op after winning',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(targetIndex)
            ..lockParam()
            ..confirmQuestion()
            ..selectQuestion(QuestionType.isOdd);
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(GameStatus.won));
          expect(cubit.state.activeQuestionType, isNull);
        },
      );

      blocTest<GameCubit, GameState>(
        'highlightCell is a no-op after winning',
        build: () => GameCubit(targetNumber: target),
        act: (cubit) {
          cubit
            ..selectQuestion(QuestionType.equals)
            ..highlightCell(targetIndex)
            ..lockParam()
            ..confirmQuestion()
            ..highlightCell(10);
        },
        verify: (cubit) {
          expect(cubit.state.highlightedCell, isNull);
        },
      );
    });

    test('GameState.numberForIndex converts correctly', () {
      expect(GameState.numberForIndex(0), equals(1));
      expect(GameState.numberForIndex(19), equals(20));
      expect(GameState.numberForIndex(399), equals(400));
    });

    test('assert fires for target out of range', () {
      expect(() => GameCubit(targetNumber: 0), throwsA(isA<AssertionError>()));
      expect(
        () => GameCubit(targetNumber: 401),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
