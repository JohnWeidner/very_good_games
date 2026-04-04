import 'package:equatable/equatable.dart';
import 'package:very_good_games/games/signal/models/cell.dart';

/// An immutable grid of cells for the Signal puzzle.
class Grid extends Equatable {
  /// Creates a [Grid] with the given [size] and flat [cells] list.
  ///
  /// The [cells] list is stored as an unmodifiable view.
  Grid({required this.size, required List<Cell> cells})
    : cells = List.unmodifiable(cells),
      assert(cells.length == size * size, 'cells.length must equal size²');

  /// The grid dimension (5 or 6).
  final int size;

  /// Flat list of cells in row-major order (unmodifiable).
  final List<Cell> cells;

  /// Returns the cell at ([row], [col]).
  Cell cellAt(int row, int col) => cells[row * size + col];

  /// Returns a new [Grid] with the cell at ([row], [col]) replaced.
  Grid setCell(int row, int col, Cell cell) {
    final newCells = List<Cell>.of(cells);
    newCells[row * size + col] = cell;
    return Grid(size: size, cells: newCells);
  }

  /// Returns all tower positions as `(row, col)` pairs.
  List<(int, int)> get towerPositions {
    final positions = <(int, int)>[];
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] is Tower) {
        positions.add((i ~/ size, i % size));
      }
    }
    return positions;
  }

  @override
  List<Object?> get props => [size, cells];
}
