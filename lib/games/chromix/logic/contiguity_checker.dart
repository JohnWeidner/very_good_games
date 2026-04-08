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

List<int> _orthogonalNeighbors(int row, int col, int size) {
  final neighbors = <int>[];
  if (row > 0) neighbors.add((row - 1) * size + col);
  if (row < size - 1) neighbors.add((row + 1) * size + col);
  if (col > 0) neighbors.add(row * size + (col - 1));
  if (col < size - 1) neighbors.add(row * size + (col + 1));
  return neighbors;
}
