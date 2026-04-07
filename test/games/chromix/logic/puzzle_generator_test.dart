import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('PuzzleGenerator', () {
    test('same seed produces identical puzzle (determinism)', () {
      const seed = 42;
      final result1 = PuzzleGenerator.generate(seed);
      final result2 = PuzzleGenerator.generate(seed);

      expect(result1.puzzle, equals(result2.puzzle));
      expect(result1.target, equals(result2.target));
      expect(result1.optimalMoves, equals(result2.optimalMoves));
    });

    test('different seeds produce different puzzles', () {
      final result1 = PuzzleGenerator.generate(100);
      final result2 = PuzzleGenerator.generate(200);

      // Very unlikely to be the same.
      expect(result1.puzzle, isNot(equals(result2.puzzle)));
    });

    test('generated puzzle has unique solution', () {
      final result = PuzzleGenerator.generate(42);
      final solveResult = PuzzleSolver.solve(
        grid: result.puzzle,
        target: result.target,
      );

      expect(solveResult.isUnique, isTrue);
    });

    test('blocker count is within 1-4 range', () {
      // Test across multiple seeds.
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        final blockerCount =
            result.puzzle.cells
                .whereType<BlockerCell>()
                .length;
        expect(
          blockerCount,
          inInclusiveRange(1, 4),
          reason: 'seed=$seed had $blockerCount blockers',
        );
      }
    });

    test('pre-filled count is within expected range', () {
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        final preFilledCount =
            result.puzzle.cells
                .whereType<ColorCell>()
                .where((c) => c.isPreFilled)
                .length;
        // Pre-filled includes both kept cells and peeled-back
        // secondaries, so total can vary. Should be at least 1.
        expect(
          preFilledCount,
          greaterThan(0),
          reason: 'seed=$seed had no pre-filled cells',
        );
      }
    });

    test('target distribution matches non-blocker cell count', () {
      final result = PuzzleGenerator.generate(42);
      final totalTarget = result.target.values.fold(
        0,
        (sum, count) => sum + count,
      );
      expect(totalTarget, equals(result.puzzle.nonBlockerCount));
    });

    test('optimalMoves is a positive value', () {
      final result = PuzzleGenerator.generate(42);
      expect(result.optimalMoves, greaterThan(0));
    });
  });
}
