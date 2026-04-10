import 'package:equatable/equatable.dart';
import 'package:very_good_games/games/chromix/models/chromix_cell.dart';
import 'package:very_good_games/games/chromix/models/chromix_color.dart';

/// An immutable 4×4 grid of [ChromixCell]s for the Chromix puzzle.
class ChromixGrid extends Equatable {
  /// Creates a [ChromixGrid] with the given flat [cells] list (16 elements).
  ChromixGrid({required List<ChromixCell> cells})
    : cells = List.unmodifiable(cells),
      assert(
        cells.length == size * size,
        'cells.length must be ${size * size}',
      );

  /// The grid dimension (always 4).
  static const size = 4;

  /// Flat list of cells in row-major order (unmodifiable).
  final List<ChromixCell> cells;

  /// Returns the cell at ([row], [col]).
  ChromixCell cellAt(int row, int col) => cells[row * size + col];

  /// Returns a new [ChromixGrid] with the cell at ([row], [col]) replaced.
  ChromixGrid setCell(int row, int col, ChromixCell cell) {
    final newCells = List<ChromixCell>.of(cells);
    newCells[row * size + col] = cell;
    return ChromixGrid(cells: newCells);
  }

  /// Counts the occurrences of each [ChromixColor] across all [ColorCell]s.
  ///
  /// Empty cells and blocker cells are excluded.
  Map<ChromixColor, int> get colorDistribution {
    final counts = <ChromixColor, int>{};
    for (final cell in cells) {
      if (cell is ColorCell) {
        counts[cell.color] = (counts[cell.color] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Whether every non-blocker cell is a [ColorCell].
  bool get isFullyFilled {
    for (final cell in cells) {
      if (cell is EmptyCell) return false;
    }
    return true;
  }

  /// The number of cells that are not [BlockerCell]s.
  int get nonBlockerCount => cells.where((cell) => cell is! BlockerCell).length;

  @override
  List<Object?> get props => [cells];
}
