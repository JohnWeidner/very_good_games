import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('PuzzleSolver', () {
    test('board with unique solution returns isUnique true', () {
      // Build a small puzzle where the solution is forced.
      // Grid: 3 blockers, 1 pre-filled secondary (locked),
      // remaining cells have exactly one way to reach the target.
      //
      // Layout:
      //   [B] [B] [B] [orange(pf)]
      //   [B] [B] [B] [B]
      //   [B] [B] [B] [B]
      //   [B] [B] [B] [empty]
      //
      // Target: {orange: 1, red: 1}
      // The empty cell must be red to match target.
      final grid = ChromixGrid(
        cells: [
          ...List.filled(3, const BlockerCell()),
          const ColorCell(ChromixColor.orange, isPreFilled: true),
          ...List.filled(11, const BlockerCell()),
          const EmptyCell(),
        ],
      );
      final target = <ChromixColor, int>{
        ChromixColor.orange: 1,
        ChromixColor.red: 1,
      };

      final result = PuzzleSolver.solve(
        grid: grid,
        target: target,
      );

      expect(result.isUnique, isTrue);
      expect(result.optimalMoves, equals(1));
    });

    test('board with multiple solutions returns isUnique false', () {
      // Two empty cells, target allows either red or blue in each.
      // Target: {red: 1, blue: 1} with 2 empty cells → 2 solutions.
      final grid = ChromixGrid(
        cells: [
          const EmptyCell(),
          const EmptyCell(),
          ...List.filled(14, const BlockerCell()),
        ],
      );
      final target = <ChromixColor, int>{
        ChromixColor.red: 1,
        ChromixColor.blue: 1,
      };

      final result = PuzzleSolver.solve(
        grid: grid,
        target: target,
      );

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

      final result = PuzzleSolver.solve(
        grid: grid,
        target: target,
      );

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

      final result = PuzzleSolver.solve(
        grid: grid,
        target: target,
      );

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

      final result = PuzzleSolver.solve(
        grid: grid,
        target: target,
      );

      expect(result.isUnique, isTrue);
      expect(result.optimalMoves, equals(0));
    });
  });
}
