import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('allGroupsContiguous', () {
    test('returns true for a fully contiguous grid', () {
      // 2x2 region of red, 2x2 region of blue, rest blockers.
      final grid = ChromixGrid(
        cells: [
          const ColorCell(ChromixColor.red),
          const ColorCell(ChromixColor.red),
          const ColorCell(ChromixColor.blue),
          const ColorCell(ChromixColor.blue),
          const ColorCell(ChromixColor.red),
          const ColorCell(ChromixColor.red),
          const ColorCell(ChromixColor.blue),
          const ColorCell(ChromixColor.blue),
          ...List.filled(8, const BlockerCell()),
        ],
      );

      expect(allGroupsContiguous(grid), isTrue);
    });

    test('returns false when a color group is disconnected', () {
      // Red in top-left and bottom-right corners (not adjacent).
      final grid = ChromixGrid(
        cells: const [
          ColorCell(ChromixColor.red), // (0,0)
          ColorCell(ChromixColor.blue), // (0,1)
          BlockerCell(), // (0,2)
          BlockerCell(), // (0,3)
          ColorCell(ChromixColor.blue), // (1,0)
          BlockerCell(), // (1,1)
          BlockerCell(), // (1,2)
          BlockerCell(), // (1,3)
          BlockerCell(), // (2,0)
          BlockerCell(), // (2,1)
          BlockerCell(), // (2,2)
          BlockerCell(), // (2,3)
          BlockerCell(), // (3,0)
          BlockerCell(), // (3,1)
          BlockerCell(), // (3,2)
          ColorCell(ChromixColor.red), // (3,3)
        ],
      );

      expect(allGroupsContiguous(grid), isFalse);
    });

    test('returns true for a single-color grid', () {
      final grid = ChromixGrid(
        cells: List.filled(16, const ColorCell(ChromixColor.red)),
      );

      expect(allGroupsContiguous(grid), isTrue);
    });

    test('returns true for grid with single-cell colors', () {
      final grid = ChromixGrid(
        cells: [
          const ColorCell(ChromixColor.red),
          const ColorCell(ChromixColor.blue),
          const ColorCell(ChromixColor.yellow),
          const BlockerCell(),
          ...List.filled(12, const BlockerCell()),
        ],
      );

      expect(allGroupsContiguous(grid), isTrue);
    });

    test('returns true for grid with blockers separating colors', () {
      // Red in top row, blue in third row, blockers between.
      final grid = ChromixGrid(
        cells: const [
          ColorCell(ChromixColor.red),
          ColorCell(ChromixColor.red),
          ColorCell(ChromixColor.red),
          ColorCell(ChromixColor.red),
          BlockerCell(),
          BlockerCell(),
          BlockerCell(),
          BlockerCell(),
          ColorCell(ChromixColor.blue),
          ColorCell(ChromixColor.blue),
          ColorCell(ChromixColor.blue),
          ColorCell(ChromixColor.blue),
          BlockerCell(),
          BlockerCell(),
          BlockerCell(),
          BlockerCell(),
        ],
      );

      expect(allGroupsContiguous(grid), isTrue);
    });

    test('handles empty cells correctly', () {
      final grid = ChromixGrid(
        cells: [
          const ColorCell(ChromixColor.red),
          const EmptyCell(),
          const EmptyCell(),
          const ColorCell(ChromixColor.red),
          ...List.filled(12, const BlockerCell()),
        ],
      );

      // Red is disconnected (separated by empty cells).
      expect(allGroupsContiguous(grid), isFalse);
    });

    test('returns true for grid with only empty and blocker cells', () {
      final grid = ChromixGrid(
        cells: [
          ...List.filled(8, const EmptyCell()),
          ...List.filled(8, const BlockerCell()),
        ],
      );

      expect(allGroupsContiguous(grid), isTrue);
    });
  });
}
