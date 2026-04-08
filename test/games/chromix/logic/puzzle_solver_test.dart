import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('PuzzleSolver', () {
    test('board with unique contiguous solution returns isUnique true',
        () {
      // Grid: all blockers except two adjacent cells.
      // Target: {red: 2}
      // Only solution: both cells are red (contiguous).
      final grid = ChromixGrid(
        cells: [
          const EmptyCell(), // (0,0)
          const EmptyCell(), // (0,1)
          ...List.filled(14, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{ChromixColor.red: 2};

      final result = PuzzleSolver.solve(grid: grid, target: target);

      expect(result.isUnique, isTrue);
      expect(result.optimalMoves, equals(2));
    });

    test(
        'board with matching distribution but non-contiguous '
        'solution returns isUnique false', () {
      // Two red cells separated by blockers — distribution matches
      // but contiguity fails.
      final grid = ChromixGrid(
        cells: [
          const EmptyCell(), // (0,0)
          const BlockerCell(), // (0,1)
          const BlockerCell(), // (0,2)
          const EmptyCell(), // (0,3)
          ...List.filled(12, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{ChromixColor.red: 2};

      final result = PuzzleSolver.solve(grid: grid, target: target);

      // Red in (0,0) and (0,3) are not adjacent — not contiguous.
      expect(result.isUnique, isFalse);
    });

    test('board with no solution returns isUnique false', () {
      // One empty cell, target requires orange (secondary) but
      // only primaries can be placed in empty cells.
      final grid = ChromixGrid(
        cells: [
          const EmptyCell(),
          ...List.filled(15, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{ChromixColor.orange: 1};

      final result = PuzzleSolver.solve(grid: grid, target: target);

      expect(result.isUnique, isFalse);
      expect(result.optimalMoves, equals(0));
    });

    test('pre-filled primary layering is explored', () {
      // One pre-filled red cell that can be layered with yellow
      // to make orange. Target requires orange.
      final grid = ChromixGrid(
        cells: [
          const ColorCell(ChromixColor.red, isPreFilled: true),
          ...List.filled(15, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{ChromixColor.orange: 1};

      final result = PuzzleSolver.solve(grid: grid, target: target);

      expect(result.isUnique, isTrue);
      expect(result.optimalMoves, equals(1));
    });

    test('pre-filled primary can be left as-is', () {
      // One pre-filled red cell. Target requires red (leave as-is).
      final grid = ChromixGrid(
        cells: [
          const ColorCell(ChromixColor.red, isPreFilled: true),
          ...List.filled(15, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{ChromixColor.red: 1};

      final result = PuzzleSolver.solve(grid: grid, target: target);

      expect(result.isUnique, isTrue);
      expect(result.optimalMoves, equals(0));
    });

    test('rejects non-contiguous solutions', () {
      // Two empty cells at (0,0) and (0,3), separated by blockers.
      // Target: {red: 1, blue: 1}
      // Both arrangements (red+blue or blue+red) produce
      // single-cell groups (contiguous), so both are valid.
      final grid = ChromixGrid(
        cells: [
          const EmptyCell(), // (0,0)
          const BlockerCell(), // (0,1)
          const BlockerCell(), // (0,2)
          const EmptyCell(), // (0,3)
          ...List.filled(12, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{
        ChromixColor.red: 1,
        ChromixColor.blue: 1,
      };

      final result = PuzzleSolver.solve(grid: grid, target: target);

      // Two valid arrangements (both contiguous since each color
      // has only 1 cell), so not unique.
      expect(result.isUnique, isFalse);
    });
  });
}
