import 'dart:collection';

import 'package:very_good_games/games/chromix/models/models.dart';

/// Checks whether all cells of each color form a single
/// orthogonally-connected group on a [ChromixGrid].
bool allGroupsContiguous(ChromixGrid grid) {
  const size = ChromixGrid.size;

  // Collect cell indices for each color.
  final colorIndices = <ChromixColor, List<int>>{};
  for (var i = 0; i < grid.cells.length; i++) {
    final cell = grid.cells[i];
    if (cell is ColorCell) {
      (colorIndices[cell.color] ??= []).add(i);
    }
  }

  // BFS from the first index of each color; all must be reachable.
  for (final entry in colorIndices.entries) {
    final indices = entry.value;
    if (indices.length <= 1) continue;

    final indexSet = indices.toSet();
    final visited = <int>{indices.first};
    final queue = Queue<int>()..add(indices.first);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final row = current ~/ size;
      final col = current % size;

      for (final neighbor in _orthogonalNeighbors(row, col, size)) {
        if (indexSet.contains(neighbor) && visited.add(neighbor)) {
          queue.add(neighbor);
        }
      }
    }

    if (visited.length != indices.length) return false;
  }

  return true;
}

/// Checks whether all cells of a single [color] form one
/// orthogonally-connected group on a [ChromixGrid].
///
/// Returns true if there are 0 or 1 cells of that color,
/// or if all cells are reachable from the first via BFS.
bool isColorGroupContiguous(ChromixGrid grid, ChromixColor color) {
  const size = ChromixGrid.size;
  final indices = <int>[];
  for (var i = 0; i < grid.cells.length; i++) {
    final cell = grid.cells[i];
    if (cell is ColorCell && cell.color == color) {
      indices.add(i);
    }
  }
  if (indices.length <= 1) return true;

  final indexSet = indices.toSet();
  final visited = <int>{indices.first};
  final queue = Queue<int>()..add(indices.first);

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    final row = current ~/ size;
    final col = current % size;

    for (final neighbor in _orthogonalNeighbors(row, col, size)) {
      if (indexSet.contains(neighbor) && visited.add(neighbor)) {
        queue.add(neighbor);
      }
    }
  }

  return visited.length == indices.length;
}

/// Checks whether any color at its target count is non-contiguous.
///
/// Only checks colors whose placed count matches their [target] count,
/// to avoid noisy feedback on partially-filled grids.
bool hasContiguityViolation(ChromixGrid grid, Map<ChromixColor, int> target) {
  final distribution = grid.colorDistribution;
  for (final entry in target.entries) {
    final color = entry.key;
    final targetCount = entry.value;
    final currentCount = distribution[color] ?? 0;

    if (currentCount == targetCount && currentCount > 1) {
      if (!isColorGroupContiguous(grid, color)) return true;
    }
  }
  return false;
}

List<int> _orthogonalNeighbors(int row, int col, int size) {
  final neighbors = <int>[];
  if (row > 0) neighbors.add((row - 1) * size + col);
  if (row < size - 1) neighbors.add((row + 1) * size + col);
  if (col > 0) neighbors.add(row * size + (col - 1));
  if (col < size - 1) neighbors.add(row * size + (col + 1));
  return neighbors;
}
