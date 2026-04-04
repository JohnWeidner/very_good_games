import 'package:very_good_games/games/signal/models/models.dart';

/// Computes the signal reach for each tower on a [Grid].
///
/// For each tower, casts rays in 4 cardinal directions, counting empty
/// cells until hitting a wall, another tower, or the grid edge.
class SignalCalculator {
  /// Returns a map of tower position `(row, col)` to its current signal
  /// count (number of empty cells reached).
  static Map<(int, int), int> calculate(Grid grid) {
    final result = <(int, int), int>{};

    for (final pos in grid.towerPositions) {
      final (row, col) = pos;
      var count = 0;

      // Cast rays in 4 cardinal directions.
      for (final (dr, dc) in _directions) {
        var r = row + dr;
        var c = col + dc;
        while (r >= 0 && r < grid.size && c >= 0 && c < grid.size) {
          final cell = grid.cellAt(r, c);
          if (cell is WallCell || cell is Tower) break;
          count++;
          r += dr;
          c += dc;
        }
      }

      result[pos] = count;
    }

    return result;
  }

  static const _directions = [(-1, 0), (1, 0), (0, -1), (0, 1)];
}
