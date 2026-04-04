import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

void main() {
  group('QuestionEvaluator', () {
    final allPossible = List.filled(400, CellState.possible);
    const target = 200;

    group('lessThan', () {
      test('eliminates numbers that fail the condition', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.lessThan,
          targetNumber: target,
          currentCells: allPossible,
          param1: 250,
        );
        expect(result.answer, contains('YES'));
        expect(result.eliminatedCount, equals(151));
        expect(result.cells[target - 1], CellState.possible);
      });

      test('when target does not satisfy, eliminates matching', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.lessThan,
          targetNumber: target,
          currentCells: allPossible,
          param1: 100,
        );
        expect(result.answer, contains('NO'));
        expect(result.eliminatedCount, equals(99));
      });
    });

    group('isOdd', () {
      test('on even target eliminates odd numbers', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.isOdd,
          targetNumber: target,
          currentCells: allPossible,
        );
        expect(result.answer, contains('NO'));
        expect(result.eliminatedCount, equals(200));
      });
    });

    group('isDivisibleBy', () {
      test('eliminates correctly', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.isDivisibleBy,
          targetNumber: target,
          currentCells: allPossible,
          param1: 10,
        );
        expect(result.answer, contains('YES'));
        expect(result.eliminatedCount, equals(360));
      });
    });

    group('isPrime', () {
      test('on non-prime target eliminates primes', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.isPrime,
          targetNumber: target,
          currentCells: allPossible,
        );
        expect(result.answer, contains('NO'));
        expect(result.eliminatedCount, greaterThan(0));
        expect(result.cells[target - 1], CellState.possible);
      });
    });

    group('onesDigitIs', () {
      test('on match eliminates non-matching digits', () {
        // 200 ends in 0. "Ends in 0?" → YES → eliminate non-zero endings.
        final result = QuestionEvaluator.apply(
          type: QuestionType.onesDigitIs,
          targetNumber: target,
          currentCells: allPossible,
          param1: 0,
        );
        expect(result.answer, contains('YES'));
        // 40 numbers end in 0 (10,20,...,400), 360 don't.
        expect(result.eliminatedCount, equals(360));
      });

      test('on mismatch eliminates matching digits', () {
        // 200 ends in 0. "Ends in 5?" → NO → eliminate numbers ending in 5.
        final result = QuestionEvaluator.apply(
          type: QuestionType.onesDigitIs,
          targetNumber: target,
          currentCells: allPossible,
          param1: 5,
        );
        expect(result.answer, contains('NO'));
        // 40 numbers end in 5 (5,15,...,395).
        expect(result.eliminatedCount, equals(40));
      });
    });

    group('equals', () {
      test('correct guess eliminates all others', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.equals,
          targetNumber: target,
          currentCells: allPossible,
          param1: target,
        );
        expect(result.answer, contains('YES'));
        expect(result.cells[target - 1], CellState.possible);
        expect(result.eliminatedCount, equals(399));
      });

      test('wrong guess marks cell as wrongGuess', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.equals,
          targetNumber: target,
          currentCells: allPossible,
          param1: 50,
        );
        expect(result.answer, contains('NO'));
        expect(result.answer, isNot(contains('too')));
        expect(result.cells[49], CellState.wrongGuess);
      });
    });

    group('shotgun', () {
      test('on miss, eliminates only the picked numbers', () {
        late QuestionResult result;
        for (var seed = 0; seed < 100; seed++) {
          result = QuestionEvaluator.apply(
            type: QuestionType.shotgun,
            targetNumber: target,
            currentCells: allPossible,
            random: Random(seed),
          );
          if (result.answer.contains('MISS')) break;
        }
        expect(result.answer, contains('MISS'));
        expect(result.cells[target - 1], CellState.possible);
        expect(result.eliminatedCount, lessThanOrEqualTo(50));
        expect(result.eliminatedCount, greaterThan(0));
      });

      test('on hit, eliminates everything not in the picks', () {
        late QuestionResult result;
        for (var seed = 0; seed < 100; seed++) {
          result = QuestionEvaluator.apply(
            type: QuestionType.shotgun,
            targetNumber: target,
            currentCells: allPossible,
            random: Random(seed),
          );
          if (result.answer.contains('HIT')) break;
        }
        expect(result.answer, contains('HIT'));
        expect(result.cells[target - 1], CellState.possible);
        expect(result.eliminatedCount, equals(350));
      });

      test('target is never eliminated regardless of outcome', () {
        for (var seed = 0; seed < 20; seed++) {
          final result = QuestionEvaluator.apply(
            type: QuestionType.shotgun,
            targetNumber: target,
            currentCells: allPossible,
            random: Random(seed),
          );
          expect(result.cells[target - 1], CellState.possible);
        }
      });
    });

    group('handGrenade', () {
      test('eliminates 20 closest cells to center', () {
        final result = QuestionEvaluator.apply(
          type: QuestionType.handGrenade,
          targetNumber: target,
          currentCells: allPossible,
          param1: 210,
        );
        expect(result.eliminatedCount, equals(20));
        expect(result.cells[target - 1], CellState.possible);
      });
    });

    test('skips already eliminated cells', () {
      final cells = List.filled(400, CellState.possible);
      cells[0] = CellState.eliminated;

      final result = QuestionEvaluator.apply(
        type: QuestionType.isOdd,
        targetNumber: target,
        currentCells: cells,
      );

      expect(result.cells[0], CellState.eliminated);
      // Number 1 (odd) was already gone — only 199 odd cells eliminated.
      expect(result.eliminatedCount, equals(199));
    });
  });
}
