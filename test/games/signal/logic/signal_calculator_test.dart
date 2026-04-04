import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/models/models.dart';

void main() {
  group('SignalCalculator', () {
    test('counts empty cells in 4 directions from tower', () {
      // 3x3 grid with tower in center, all empty around it.
      final grid = Grid(
        size: 3,
        cells: [
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.tower(4),
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      expect(signals[(1, 1)], equals(4));
    });

    test('stops at walls', () {
      // Tower at (1,1), wall at (1,2) blocks right.
      final grid = Grid(
        size: 3,
        cells: [
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.tower(3),
          Cell.wall,
          Cell.empty,
          Cell.empty,
          Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      // Up(1) + Down(1) + Left(1) + Right(0, blocked by wall) = 3
      expect(signals[(1, 1)], equals(3));
    });

    test('stops at other towers', () {
      // Two towers on same row.
      final grid = Grid(
        size: 3,
        cells: [
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.tower(1),
          Cell.empty,
          Cell.tower(1),
          Cell.empty,
          Cell.empty,
          Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      // Left tower: Up(1) + Down(1) + Left(0) + Right(1) = 3...
      // but right is blocked by right tower at (1,2),
      // so: Up(1) + Down(1) + Left(0, edge) + Right(1) = 3
      expect(signals[(1, 0)], equals(3));
      // Right tower: Up(1) + Down(1) + Left(1) + Right(0, edge) = 3
      expect(signals[(1, 2)], equals(3));
    });

    test('tower at corner has limited reach', () {
      final grid = Grid(
        size: 3,
        cells: [
          Cell.tower(4),
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
          Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      // Right(2) + Down(2) = 4
      expect(signals[(0, 0)], equals(4));
    });

    test('empty grid with single tower', () {
      final grid = Grid(
        size: 5,
        cells: [
          for (var i = 0; i < 25; i++)
            if (i == 12) Cell.tower(8) else Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      // Center of 5x5: 2 in each direction = 8
      expect(signals[(2, 2)], equals(8));
    });

    test('tower completely surrounded by walls', () {
      final grid = Grid(
        size: 3,
        cells: [
          Cell.empty,
          Cell.wall,
          Cell.empty,
          Cell.wall,
          Cell.tower(0),
          Cell.wall,
          Cell.empty,
          Cell.wall,
          Cell.empty,
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      expect(signals[(1, 1)], equals(0));
    });

    test('handles multiple towers with independent signals', () {
      final grid = Grid(
        size: 3,
        cells: [
          Cell.tower(2),
          Cell.empty,
          Cell.tower(2),
          Cell.empty,
          Cell.wall,
          Cell.empty,
          Cell.tower(2),
          Cell.empty,
          Cell.tower(2),
        ],
      );

      final signals = SignalCalculator.calculate(grid);

      expect(signals.length, equals(4));
      // Each corner tower can reach 2 cells (along edges, blocked
      // by wall in center on adjacent row/col via another tower).
      // Top-left: Right blocked by top-right tower (1 cell),
      //           Down blocked by bottom-left tower (1 cell) = 2
      expect(signals[(0, 0)], equals(2));
    });
  });
}
