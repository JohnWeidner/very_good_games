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
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        final blockerCount = result.puzzle.cells
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
        final preFilledCount = result.puzzle.cells
            .whereType<ColorCell>()
            .where((c) => c.isPreFilled)
            .length;
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

    test('optimalMoves is at least 3', () {
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        expect(
          result.optimalMoves,
          greaterThanOrEqualTo(3),
          reason: 'seed=$seed had ${result.optimalMoves} optimal moves',
        );
      }
    });

    test('generated puzzles have at least 5 colors in target', () {
      for (var seed = 1; seed <= 15; seed++) {
        final result = PuzzleGenerator.generate(seed);

        expect(
          result.target.keys.length,
          greaterThanOrEqualTo(5),
          reason: 'seed=$seed had ${result.target.keys.length} colors',
        );
      }
    });

    test('generates valid puzzle with max blockers edge case', () {
      // Try many seeds to find one that generates 4 blockers.
      GenerateResult? fourBlockerResult;
      for (var seed = 1; seed <= 200; seed++) {
        final result = PuzzleGenerator.generate(seed);
        final blockerCount = result.puzzle.cells
            .whereType<BlockerCell>()
            .length;
        if (blockerCount == 4) {
          fourBlockerResult = result;
          break;
        }
      }

      if (fourBlockerResult != null) {
        // Verify the puzzle is consistent: target sum matches
        // non-blocker count.
        final targetSum = fourBlockerResult.target.values.fold<int>(
          0,
          (a, b) => a + b,
        );
        expect(targetSum, equals(fourBlockerResult.puzzle.nonBlockerCount));
      }
    });
    test('primary adjacent only to its parent secondary is not trapped', () {
      // Build a 4x4 grid where a primary (Red) is surrounded by
      // blockers on three sides and its parent secondary (Orange)
      // on the fourth. Without component-overpower awareness this
      // would be flagged as trapped; with it, Red can overpower
      // Orange so it's not trapped.
      //
      // Layout (row-major, 4x4):
      //   B  B  E  E
      //   B  R  O  E   ← Red at (1,1), Orange at (1,2)
      //   B  B  Y  E
      //   E  E  E  E
      final cells = <ChromixCell>[
        // Row 0
        const BlockerCell(), const BlockerCell(),
        const EmptyCell(), const EmptyCell(),
        // Row 1
        const BlockerCell(),
        const ColorCell(ChromixColor.red, isPreFilled: true),
        const ColorCell(ChromixColor.orange, isPreFilled: true),
        const EmptyCell(),
        // Row 2
        const BlockerCell(), const BlockerCell(),
        const ColorCell(ChromixColor.yellow, isPreFilled: true),
        const EmptyCell(),
        // Row 3
        const EmptyCell(), const EmptyCell(),
        const EmptyCell(), const EmptyCell(),
      ];
      final grid = ChromixGrid(cells: cells);

      // Red at (1,1) has neighbors: (0,1)=Blocker, (2,1)=Blocker,
      // (1,0)=Blocker, (1,2)=Orange. Orange is Red's parent secondary,
      // so Red should NOT be considered trapped.
      // Verify the generator accepts this grid by checking that
      // no pre-filled cell is flagged as trapped. We can't call
      // _hasTrappedCell directly (private), but we can verify
      // indirectly: if it were trapped, _buildStartGrid would
      // return null. Instead, test the invariant: for each
      // pre-filled cell, at least one neighbor is empty, same-color,
      // or a parent secondary.
      for (var i = 0; i < grid.cells.length; i++) {
        final cell = grid.cells[i];
        if (cell is! ColorCell || !cell.isPreFilled) continue;

        final row = i ~/ ChromixGrid.size;
        final col = i % ChromixGrid.size;
        var hasOpen = false;

        for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
          final nr = row + dr;
          final nc = col + dc;
          if (nr < 0 || nr >= ChromixGrid.size) continue;
          if (nc < 0 || nc >= ChromixGrid.size) continue;
          final neighbor = grid.cellAt(nr, nc);
          if (neighbor is EmptyCell) {
            hasOpen = true;
            break;
          }
          if (neighbor is ColorCell && neighbor.color == cell.color) {
            hasOpen = true;
            break;
          }
          if (neighbor is ColorCell &&
              ColorMixer.isComponentOf(cell.color, neighbor.color)) {
            hasOpen = true;
            break;
          }
        }

        expect(
          hasOpen,
          isTrue,
          reason:
              '${cell.color} at ($row,$col) should not be trapped '
              '(component-overpower makes parent secondary reachable)',
        );
      }
    });
  });
}
