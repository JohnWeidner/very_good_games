import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('ChromixGrid', () {
    ChromixGrid makeGrid(List<ChromixCell> cells) =>
        ChromixGrid(cells: cells);

    // A simple 4x4 grid for testing.
    late ChromixGrid grid;

    setUp(() {
      grid = makeGrid([
        // Row 0
        const EmptyCell(),
        const ColorCell(ChromixColor.red),
        const BlockerCell(),
        const ColorCell(ChromixColor.orange),
        // Row 1
        const ColorCell(ChromixColor.yellow),
        const EmptyCell(),
        const ColorCell(ChromixColor.blue),
        const ColorCell(ChromixColor.green),
        // Row 2
        const BlockerCell(),
        const ColorCell(ChromixColor.purple),
        const EmptyCell(),
        const ColorCell(ChromixColor.red),
        // Row 3
        const ColorCell(ChromixColor.yellow),
        const ColorCell(ChromixColor.blue),
        const ColorCell(ChromixColor.orange),
        const EmptyCell(),
      ]);
    });

    test('cellAt returns correct cell', () {
      expect(grid.cellAt(0, 0), equals(const EmptyCell()));
      expect(
        grid.cellAt(0, 1),
        equals(const ColorCell(ChromixColor.red)),
      );
      expect(grid.cellAt(0, 2), equals(const BlockerCell()));
      expect(
        grid.cellAt(1, 3),
        equals(const ColorCell(ChromixColor.green)),
      );
    });

    test('setCell returns new grid with replaced cell', () {
      final updated = grid.setCell(
        0,
        0,
        const ColorCell(ChromixColor.blue),
      );

      expect(
        updated.cellAt(0, 0),
        equals(const ColorCell(ChromixColor.blue)),
      );
      // Original is unchanged.
      expect(grid.cellAt(0, 0), equals(const EmptyCell()));
    });

    test('colorDistribution counts colors correctly', () {
      final dist = grid.colorDistribution;

      expect(dist[ChromixColor.red], equals(2));
      expect(dist[ChromixColor.yellow], equals(2));
      expect(dist[ChromixColor.blue], equals(2));
      expect(dist[ChromixColor.orange], equals(2));
      expect(dist[ChromixColor.green], equals(1));
      expect(dist[ChromixColor.purple], equals(1));
    });

    test('colorDistribution excludes empty and blocker cells', () {
      final allEmpty = makeGrid(
        List.filled(16, const EmptyCell()),
      );
      expect(allEmpty.colorDistribution, isEmpty);
    });

    test('isFullyFilled returns false when empty cells exist', () {
      expect(grid.isFullyFilled, isFalse);
    });

    test('isFullyFilled returns true when no empty cells exist', () {
      final full = makeGrid(
        List.generate(16, (i) {
          if (i == 0 || i == 5) return const BlockerCell();
          return const ColorCell(ChromixColor.red);
        }),
      );
      expect(full.isFullyFilled, isTrue);
    });

    test(
      'isFullyFilled returns true with only blockers and colors',
      () {
        final full = makeGrid([
          ...List.filled(4, const BlockerCell()),
          ...List.filled(12, const ColorCell(ChromixColor.blue)),
        ]);
        expect(full.isFullyFilled, isTrue);
      },
    );

    test('nonBlockerCount excludes blockers', () {
      // 2 blockers in setUp grid.
      expect(grid.nonBlockerCount, equals(14));
    });

    test('nonBlockerCount for all-blocker grid', () {
      final allBlockers = makeGrid(
        List.filled(16, const BlockerCell()),
      );
      expect(allBlockers.nonBlockerCount, equals(0));
    });

    test('is equatable', () {
      final a = makeGrid(
        List.filled(16, const ColorCell(ChromixColor.red)),
      );
      final b = makeGrid(
        List.filled(16, const ColorCell(ChromixColor.red)),
      );
      final c = makeGrid(
        List.filled(16, const ColorCell(ChromixColor.blue)),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
