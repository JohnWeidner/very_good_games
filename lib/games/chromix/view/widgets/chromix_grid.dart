import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart'
    as models;
import 'package:very_good_games/games/chromix/view/widgets/chromix_cell_widget.dart';

/// A 4x4 grid of [ChromixCellWidget]s with drag gesture support.
///
/// Adjacent same-color cells visually merge into blobs by sharing
/// edges (no gap, no rounded corner between them).
class ChromixGrid extends StatelessWidget {
  /// Creates a [ChromixGrid].
  const ChromixGrid({super.key});

  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChromixCubit, ChromixState>(
      buildWhen: (prev, curr) =>
          prev.grid != curr.grid ||
          prev.dragOrigin != curr.dragOrigin,
      builder: (context, state) {
        return AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridSize = constraints.maxWidth;
              final cellSize = gridSize / models.ChromixGrid.size;

              return GestureDetector(
                onPanStart: (details) => _onPanStart(
                  context,
                  details.localPosition,
                  cellSize,
                ),
                onPanUpdate: (details) => _onPanUpdate(
                  context,
                  details.localPosition,
                  cellSize,
                ),
                onPanEnd: (_) =>
                    context.read<ChromixCubit>().endDrag(),
                onPanCancel: () =>
                    context.read<ChromixCubit>().endDrag(),
                child: _buildGrid(context, state, cellSize),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    ChromixState state,
    double cellSize,
  ) {
    const size = models.ChromixGrid.size;
    final grid = state.grid;
    final blobs = _computeBlobs(grid);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cell backgrounds.
        for (var row = 0; row < size; row++)
          for (var col = 0; col < size; col++)
            _buildCell(state, grid, row, col, cellSize),
        // Floating blob labels.
        for (final blob in blobs)
          _buildBlobLabel(context, blob, cellSize),
      ],
    );
  }

  Widget _buildCell(
    ChromixState state,
    models.ChromixGrid grid,
    int row,
    int col,
    double cellSize,
  ) {
    final cell = grid.cellAt(row, col);
    final edges = _computeEdges(grid, row, col);
    final isOrigin = state.dragOrigin != null &&
        state.dragOrigin!.row == row &&
        state.dragOrigin!.col == col;

    const overlap = 0.5;
    final left =
        col * cellSize + (edges.left ? -overlap : _gap / 2);
    final top =
        row * cellSize + (edges.top ? -overlap : _gap / 2);
    final right =
        (col + 1) * cellSize - (edges.right ? -overlap : _gap / 2);
    final bottom =
        (row + 1) * cellSize - (edges.bottom ? -overlap : _gap / 2);

    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: ChromixCellWidget(
        cell: cell,
        edges: edges,
        isHighlighted: isOrigin,
      ),
    );
  }

  Widget _buildBlobLabel(
    BuildContext context,
    _Blob blob,
    double cellSize,
  ) {
    const size = models.ChromixGrid.size;
    final blobSet = blob.cells.toSet();

    // Find the most interior cells (highest blob-neighbor count),
    // then place the label at the centroid of those cells. This
    // centers the label within the thickest part of the blob, and
    // for even-sized blobs it naturally lands between cells.
    var bestNeighborCount = -1;
    final candidates = <int>[];

    for (final idx in blob.cells) {
      final row = idx ~/ size;
      final col = idx % size;
      var neighborCount = 0;
      for (final n in _neighborsOf(row, col)) {
        if (blobSet.contains(n)) neighborCount++;
      }
      if (neighborCount > bestNeighborCount) {
        bestNeighborCount = neighborCount;
        candidates
          ..clear()
          ..add(idx);
      } else if (neighborCount == bestNeighborCount) {
        candidates.add(idx);
      }
    }

    // Place at the centroid of the most interior cells.
    var sumCx = 0.0;
    var sumCy = 0.0;
    for (final idx in candidates) {
      sumCx += (idx % size + 0.5) * cellSize;
      sumCy += (idx ~/ size + 0.5) * cellSize;
    }
    final cx = sumCx / candidates.length;
    final cy = sumCy / candidates.length;

    final letter = _letterFor(blob.color);
    final textColor = blob.color == models.ChromixColor.yellow
        ? Colors.black
        : Colors.white;

    return Positioned(
      left: cx - cellSize / 2,
      top: cy - cellSize / 2,
      width: cellSize,
      height: cellSize,
      child: IgnorePointer(
        child: Center(
          child: Text(
            letter,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Finds all connected blobs of same-color cells via flood-fill.
  static List<_Blob> _computeBlobs(models.ChromixGrid grid) {
    const size = models.ChromixGrid.size;
    final visited = <int>{};
    final blobs = <_Blob>[];

    for (var i = 0; i < grid.cells.length; i++) {
      if (visited.contains(i)) continue;
      final cell = grid.cells[i];
      if (cell is! models.ColorCell) {
        visited.add(i);
        continue;
      }

      final color = cell.color;
      final blob = <int>[];
      final queue = [i];
      visited.add(i);

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        blob.add(current);
        final row = current ~/ size;
        final col = current % size;

        for (final n in _neighborsOf(row, col)) {
          if (visited.contains(n)) continue;
          final nc = grid.cells[n];
          if (nc is models.ColorCell && nc.color == color) {
            visited.add(n);
            queue.add(n);
          }
        }
      }

      blobs.add(_Blob(color: color, cells: blob));
    }

    return blobs;
  }

  static List<int> _neighborsOf(int row, int col) {
    const size = models.ChromixGrid.size;
    return [
      if (row > 0) (row - 1) * size + col,
      if (row < size - 1) (row + 1) * size + col,
      if (col > 0) row * size + (col - 1),
      if (col < size - 1) row * size + (col + 1),
    ];
  }

  /// Determines which edges of the cell at ([row], [col]) share a
  /// visual identity with their orthogonal neighbor (same color, or
  /// both blockers).
  static CellEdges _computeEdges(
    models.ChromixGrid grid,
    int row,
    int col,
  ) {
    final cell = grid.cellAt(row, col);
    if (cell is models.EmptyCell) return CellEdges.none;

    return CellEdges(
      top: _sameVisual(grid, cell, row - 1, col),
      bottom: _sameVisual(grid, cell, row + 1, col),
      left: _sameVisual(grid, cell, row, col - 1),
      right: _sameVisual(grid, cell, row, col + 1),
    );
  }

  /// Whether the cell at ([row], [col]) has the same visual identity
  /// as [cell] — same ChromixColor, or both BlockerCells.
  static bool _sameVisual(
    models.ChromixGrid grid,
    models.ChromixCell cell,
    int row,
    int col,
  ) {
    if (row < 0 ||
        row >= models.ChromixGrid.size ||
        col < 0 ||
        col >= models.ChromixGrid.size) {
      return false;
    }
    final neighbor = grid.cellAt(row, col);
    if (cell is models.BlockerCell && neighbor is models.BlockerCell) {
      return true;
    }
    if (cell is models.ColorCell && neighbor is models.ColorCell) {
      return cell.color == neighbor.color;
    }
    return false;
  }

  void _onPanStart(
    BuildContext context,
    Offset localPosition,
    double cellSize,
  ) {
    final pos = _cellFromOffset(localPosition, cellSize);
    if (pos == null) return;
    context.read<ChromixCubit>().startDrag(pos.row, pos.col);
  }

  void _onPanUpdate(
    BuildContext context,
    Offset localPosition,
    double cellSize,
  ) {
    final pos = _cellFromOffset(localPosition, cellSize);
    if (pos == null) return;
    context.read<ChromixCubit>().dragTo(pos.row, pos.col);
  }

  static ({int row, int col})? _cellFromOffset(
    Offset offset,
    double cellSize,
  ) {
    final col = (offset.dx / cellSize).floor();
    final row = (offset.dy / cellSize).floor();

    if (row < 0 ||
        row >= models.ChromixGrid.size ||
        col < 0 ||
        col >= models.ChromixGrid.size) {
      return null;
    }
    return (row: row, col: col);
  }

  static String _letterFor(models.ChromixColor color) => switch (color) {
    models.ChromixColor.red => 'R',
    models.ChromixColor.yellow => 'Y',
    models.ChromixColor.blue => 'B',
    models.ChromixColor.orange => 'O',
    models.ChromixColor.green => 'G',
    models.ChromixColor.purple => 'P',
  };
}

class _Blob {
  const _Blob({required this.color, required this.cells});

  final models.ChromixColor color;
  final List<int> cells;
}
