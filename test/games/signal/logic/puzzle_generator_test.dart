import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/models/models.dart';

void main() {
  group('PuzzleGenerator', () {
    test('same seed produces identical puzzle (determinism)', () {
      const seed = 42;

      final result1 = PuzzleGenerator.generate(seed);
      final result2 = PuzzleGenerator.generate(seed);

      expect(result1.puzzle, equals(result2.puzzle));
      expect(result1.solutionWallCount, equals(result2.solutionWallCount));
    });

    test('different seeds produce different puzzles', () {
      final result1 = PuzzleGenerator.generate(42);
      final result2 = PuzzleGenerator.generate(99);

      expect(result1.puzzle, isNot(equals(result2.puzzle)));
    });

    test('generates 5x5 grid when seed % 3 != 0', () {
      // seed=1, 1 % 3 = 1 != 0 → 5x5
      final result = PuzzleGenerator.generate(1);

      expect(result.puzzle.size, equals(5));
      expect(result.puzzle.cells.length, equals(25));
    });

    test('generates 6x6 grid when seed % 3 == 0', () {
      // seed=3, 3 % 3 = 0 → 6x6
      final result = PuzzleGenerator.generate(3);

      expect(result.puzzle.size, equals(6));
      expect(result.puzzle.cells.length, equals(36));
    });

    test('puzzle contains only towers and empty cells (no walls)', () {
      final result = PuzzleGenerator.generate(42);

      for (final cell in result.puzzle.cells) {
        expect(cell, isNot(isA<WallCell>()));
      }
    });

    test('puzzle has at least 3 towers', () {
      // Test with multiple seeds.
      for (var seed = 0; seed < 5; seed++) {
        final result = PuzzleGenerator.generate(seed);
        expect(
          result.puzzle.towerPositions.length,
          greaterThanOrEqualTo(3),
          reason: 'seed=$seed should have >= 3 towers',
        );
      }
    });

    test('solutionWallCount is positive', () {
      for (var seed = 0; seed < 5; seed++) {
        final result = PuzzleGenerator.generate(seed);
        expect(
          result.solutionWallCount,
          greaterThan(0),
          reason: 'seed=$seed should have positive wall count',
        );
      }
    });

    test('all tower targetCounts are non-negative', () {
      for (var seed = 0; seed < 5; seed++) {
        final result = PuzzleGenerator.generate(seed);
        for (final cell in result.puzzle.cells) {
          if (cell is Tower) {
            expect(
              cell.targetCount,
              greaterThanOrEqualTo(0),
              reason: 'seed=$seed towers should have non-negative targets',
            );
          }
        }
      }
    });

    test('5x5 puzzle has 3-5 towers', () {
      // seed=1 → 5x5
      final result = PuzzleGenerator.generate(1);
      final towerCount = result.puzzle.towerPositions.length;

      expect(towerCount, inInclusiveRange(3, 5));
    });

    test('6x6 puzzle has 4-7 towers', () {
      // seed=3 → 6x6
      final result = PuzzleGenerator.generate(3);
      final towerCount = result.puzzle.towerPositions.length;

      expect(towerCount, inInclusiveRange(4, 7));
    });
  });
}
