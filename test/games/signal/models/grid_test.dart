import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/models/models.dart';

void main() {
  group('Grid', () {
    test('cellAt returns correct cell', () {
      final grid = Grid(
        size: 3,
        cells: [
          Cell.empty,
          Cell.wall,
          Cell.tower(2),
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.wall,
          Cell.empty,
          Cell.tower(1),
        ],
      );

      expect(grid.cellAt(0, 0), equals(Cell.empty));
      expect(grid.cellAt(0, 1), equals(Cell.wall));
      expect(grid.cellAt(0, 2), equals(Cell.tower(2)));
      expect(grid.cellAt(2, 0), equals(Cell.wall));
      expect(grid.cellAt(2, 2), equals(Cell.tower(1)));
    });

    test('setCell returns new grid with replaced cell', () {
      final grid = Grid(
        size: 2,
        cells: const [Cell.empty, Cell.empty, Cell.empty, Cell.empty],
      );

      final updated = grid.setCell(0, 1, Cell.wall);

      expect(updated.cellAt(0, 1), equals(Cell.wall));
      // Original is unchanged.
      expect(grid.cellAt(0, 1), equals(Cell.empty));
    });

    test('towerPositions returns all tower locations', () {
      final grid = Grid(
        size: 3,
        cells: [
          Cell.tower(2),
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.tower(3),
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.tower(1),
        ],
      );

      expect(grid.towerPositions, equals([(0, 0), (1, 1), (2, 2)]));
    });

    test('towerPositions returns empty list when no towers', () {
      final grid = Grid(
        size: 2,
        cells: const [Cell.empty, Cell.wall, Cell.empty, Cell.wall],
      );

      expect(grid.towerPositions, isEmpty);
    });

    test('is equatable', () {
      final a = Grid(
        size: 2,
        cells: [Cell.empty, Cell.wall, Cell.tower(1), Cell.empty],
      );
      final b = Grid(
        size: 2,
        cells: [Cell.empty, Cell.wall, Cell.tower(1), Cell.empty],
      );
      final c = Grid(
        size: 2,
        cells: [Cell.empty, Cell.empty, Cell.tower(1), Cell.empty],
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
