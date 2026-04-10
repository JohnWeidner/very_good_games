import 'package:flutter/material.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/theme/theme.dart';

/// Which edges of this cell share a color with their neighbor.
class CellEdges {
  /// Creates [CellEdges].
  const CellEdges({
    this.top = false,
    this.bottom = false,
    this.left = false,
    this.right = false,
  });

  /// No edges shared (cell is isolated).
  static const none = CellEdges();

  /// Whether the cell above has the same color.
  final bool top;

  /// Whether the cell below has the same color.
  final bool bottom;

  /// Whether the cell to the left has the same color.
  final bool left;

  /// Whether the cell to the right has the same color.
  final bool right;
}

/// Renders a single cell in the Chromix grid.
///
/// Uses [edges] to determine which corners to round, creating a visual
/// "blob" effect where adjacent same-color cells merge together.
class ChromixCellWidget extends StatelessWidget {
  /// Creates a [ChromixCellWidget].
  const ChromixCellWidget({
    required this.cell,
    this.edges = CellEdges.none,
    this.isHighlighted = false,
    super.key,
  });

  /// The cell to render.
  final ChromixCell cell;

  /// Which edges are shared with same-color neighbors.
  final CellEdges edges;

  /// Whether this cell is the current drag origin.
  final bool isHighlighted;

  static const _radius = Radius.circular(10);
  static const _zero = Radius.zero;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: _borderRadius,
        border: _border,
      ),
      child: const SizedBox.shrink(),
    );
  }

  /// Round a corner only if neither orthogonal neighbor at that corner
  /// shares the same color.
  BorderRadius get _borderRadius => BorderRadius.only(
    topLeft: (!edges.top && !edges.left) ? _radius : _zero,
    topRight: (!edges.top && !edges.right) ? _radius : _zero,
    bottomLeft: (!edges.bottom && !edges.left) ? _radius : _zero,
    bottomRight: (!edges.bottom && !edges.right) ? _radius : _zero,
  );

  Color get _backgroundColor => switch (cell) {
    EmptyCell() => ChromixColors.empty,
    BlockerCell() => ChromixColors.blocker,
    ColorCell(color: final c) => _colorFor(c),
  };

  Border? get _border {
    if (isHighlighted) {
      return Border.all(color: Colors.white, width: 3);
    }
    return null;
  }

  static Color _colorFor(ChromixColor color) => switch (color) {
    ChromixColor.red => ChromixColors.red,
    ChromixColor.yellow => ChromixColors.yellow,
    ChromixColor.blue => ChromixColors.blue,
    ChromixColor.orange => ChromixColors.orange,
    ChromixColor.green => ChromixColors.green,
    ChromixColor.purple => ChromixColors.purple,
  };
}
