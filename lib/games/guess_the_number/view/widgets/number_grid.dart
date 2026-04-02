import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/theme/game_colors.dart';

/// A 20x20 grid of circles representing numbers 1–400.
///
/// Uses [CustomPaint] for smooth 60fps rendering of all 400 cells.
/// During selection mode, a magnifying lens appears above the touch
/// point showing a zoomed 5x5 area with numbers on each cell.
class NumberGrid extends StatefulWidget {
  /// Creates a [NumberGrid].
  const NumberGrid({
    required this.cells,
    required this.onCellHighlighted,
    required this.onCellSelected,
    this.highlightedCell,
    this.selectedCells = const {},
    this.isSelecting = false,
    super.key,
  });

  /// The state of each of the 400 cells.
  final List<CellState> cells;

  /// Called as the player drags their finger — reports the cell index
  /// currently under the finger, or `null` when the finger leaves.
  final ValueChanged<int?> onCellHighlighted;

  /// Called when the player lifts their finger on a cell.
  final ValueChanged<int> onCellSelected;

  /// The index of the currently highlighted cell, if any.
  final int? highlightedCell;

  /// Cell indices that have been locked as parameters and should
  /// show a persistent selection ring on the grid.
  final Set<int> selectedCells;

  /// Whether the grid is in selection mode (a question card is staged).
  /// When true, the zoom lens appears on touch.
  final bool isSelecting;

  /// Number of columns in the grid.
  static const columns = 20;

  /// Number of rows in the grid.
  static const rows = 20;

  /// Width reserved for row labels on the left edge.
  static const rowLabelWidth = 36.0;

  /// Converts a data index (0-based) to (visualCol, visualRow).
  static (int col, int visualRow) visualPosition(int index) {
    final col = index % columns;
    final dataRow = index ~/ columns;
    final visualRow = (rows - 1) - dataRow;
    return (col, visualRow);
  }

  /// Converts (col, visualRow) to a data index.
  static int dataIndex(int col, int visualRow) {
    final dataRow = (rows - 1) - visualRow;
    return dataRow * columns + col;
  }

  @override
  State<NumberGrid> createState() => _NumberGridState();
}

class _NumberGridState extends State<NumberGrid> {
  /// Key for the grid area so we can convert local → global coords.
  final _gridKey = GlobalKey();

  OverlayEntry? _lensOverlay;

  @override
  void dispose() {
    _removeLens();
    super.dispose();
  }

  @override
  void didUpdateWidget(NumberGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Remove lens if selection mode was turned off externally
    // (e.g., question cancelled, game won).
    if (!widget.isSelecting && _lensOverlay != null) {
      _removeLens();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth =
            constraints.maxWidth - NumberGrid.rowLabelWidth;
        final cellSize = gridWidth / NumberGrid.columns;
        final gridHeight = cellSize * NumberGrid.rows;

        return SizedBox(
          height: gridHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row labels.
              SizedBox(
                width: NumberGrid.rowLabelWidth,
                height: gridHeight,
                child: CustomPaint(
                  painter: _RowLabelPainter(
                    cellSize: cellSize,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
              // The interactive grid.
              Expanded(
                child: GestureDetector(
                  onPanStart: (d) =>
                      _onTouch(d.localPosition, cellSize, gridWidth),
                  onPanUpdate: (d) =>
                      _onTouch(d.localPosition, cellSize, gridWidth),
                  onPanEnd: (_) => _onLift(),
                  onTapUp: (d) {
                    _onTouch(
                      d.localPosition,
                      cellSize,
                      gridWidth,
                    );
                    _onLift();
                  },
                  child: CustomPaint(
                    key: _gridKey,
                    size: Size(gridWidth, gridHeight),
                    painter: _GridPainter(
                      cells: widget.cells,
                      highlightedCell: widget.highlightedCell,
                      selectedCells: widget.selectedCells,
                      cellSize: cellSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTouch(
    Offset localPosition,
    double cellSize,
    double gridWidth,
  ) {
    final col = (localPosition.dx / cellSize).floor();
    final row = (localPosition.dy / cellSize).floor();

    if (col < 0 ||
        col >= NumberGrid.columns ||
        row < 0 ||
        row >= NumberGrid.rows) {
      widget.onCellHighlighted(null);
      _removeLens();
      return;
    }

    final index = NumberGrid.dataIndex(col, row);
    widget.onCellHighlighted(index);

    _showLens(localPosition, gridWidth, cellSize, index);
  }

  void _onLift() {
    if (widget.highlightedCell != null) {
      widget.onCellSelected(widget.highlightedCell!);
    }
    widget.onCellHighlighted(null);
    _removeLens();
  }

  void _showLens(
    Offset localPosition,
    double gridWidth,
    double cellSize,
    int cellIndex,
  ) {
    // Convert local grid position to global screen position.
    final renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final globalPosition = renderBox.localToGlobal(localPosition);

    const lensWidth =
        _ZoomLens.lensColumns * _ZoomLens.zoomedCellSize;
    const lensHeight =
        _ZoomLens.lensRows * _ZoomLens.zoomedCellSize;

    // Horizontal: centered on touch, no clamping — allow overflow.
    final left = globalPosition.dx - lensWidth / 2;

    // Vertical: always above the finger.
    final top = globalPosition.dy - lensHeight - 32;

    _removeLens();
    _lensOverlay = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: _ZoomLens(
            cells: widget.cells,
            centerIndex: cellIndex,
            cellSize: cellSize,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_lensOverlay!);
  }

  void _removeLens() {
    _lensOverlay?.remove();
    _lensOverlay?.dispose();
    _lensOverlay = null;
  }
}

/// A magnifying lens showing a zoomed 5x5 area of the grid.
///
/// Each cell in the lens is large enough to display its number and
/// shows the cell state color. The center cell (under the finger)
/// has a highlight ring.
class _ZoomLens extends StatelessWidget {
  const _ZoomLens({
    required this.cells,
    required this.centerIndex,
    required this.cellSize,
  });

  final List<CellState> cells;
  final int centerIndex;
  final double cellSize;

  /// How many columns/rows the lens shows.
  static const lensColumns = 5;
  static const lensRows = 5;

  /// Size of each cell in the zoomed view.
  static const zoomedCellSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (centerCol, centerVisualRow) =
        NumberGrid.visualPosition(centerIndex);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          size: const Size(
            lensColumns * zoomedCellSize,
            lensRows * zoomedCellSize,
          ),
          painter: _ZoomLensPainter(
            cells: cells,
            centerCol: centerCol,
            centerVisualRow: centerVisualRow,
          ),
        ),
      ),
    );
  }
}

/// Paints the zoomed 5x5 grid inside the lens with numbers on cells.
class _ZoomLensPainter extends CustomPainter {
  _ZoomLensPainter({
    required this.cells,
    required this.centerCol,
    required this.centerVisualRow,
  });

  final List<CellState> cells;
  final int centerCol;
  final int centerVisualRow;

  @override
  void paint(Canvas canvas, Size size) {
    const zcs = _ZoomLens.zoomedCellSize;
    const radius = zcs * 0.38;
    final paint = Paint()..style = PaintingStyle.fill;
    const halfLens = 2; // 5x5 → center ± 2

    for (var dy = -halfLens; dy <= halfLens; dy++) {
      for (var dx = -halfLens; dx <= halfLens; dx++) {
        final col = centerCol + dx;
        final visualRow = centerVisualRow + dy;

        final lensCol = dx + halfLens;
        final lensRow = dy + halfLens;
        final center = Offset(
          lensCol * zcs + zcs / 2,
          lensRow * zcs + zcs / 2,
        );

        // Out-of-bounds cells draw as empty.
        if (col < 0 ||
            col >= NumberGrid.columns ||
            visualRow < 0 ||
            visualRow >= NumberGrid.rows) {
          paint.color = const Color(0xFFEEEEEE);
          canvas.drawCircle(center, radius, paint);
          continue;
        }

        final index = NumberGrid.dataIndex(col, visualRow);
        final cellState = cells[index];
        paint.color = GameColors.forCellState(cellState);
        canvas.drawCircle(center, radius, paint);

        // Draw the number on the cell.
        final number = index + 1;
        final isCenter = dx == 0 && dy == 0;
        final textColor = cellState == CellState.possible
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF757575);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$number',
            style: TextStyle(
              color: textColor,
              fontSize: isCenter ? 14 : 11,
              fontWeight:
                  isCenter ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );

        // Highlight ring on center cell.
        if (isCenter) {
          final ringPaint = Paint()
            ..style = PaintingStyle.stroke
            ..color = GameColors.highlight
            ..strokeWidth = 3;
          canvas.drawCircle(center, radius + 2, ringPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ZoomLensPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.centerCol != centerCol ||
        oldDelegate.centerVisualRow != centerVisualRow;
  }
}

/// Paints the 20x20 grid of circles.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cells,
    required this.cellSize,
    this.highlightedCell,
    this.selectedCells = const {},
  });

  final List<CellState> cells;
  final double cellSize;
  final int? highlightedCell;
  final Set<int> selectedCells;

  static const _bandRows = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()..color = const Color(0x08000000);
    const bandCount = NumberGrid.rows ~/ _bandRows;
    for (var bandRow = 1; bandRow < bandCount; bandRow += 2) {
      final y = bandRow * _bandRows * cellSize;
      final bandHeight = _bandRows * cellSize;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, bandHeight),
        bandPaint,
      );
    }

    final radius = cellSize * 0.38;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < cells.length; i++) {
      final (col, visualRow) = NumberGrid.visualPosition(i);
      final center = Offset(
        col * cellSize + cellSize / 2,
        visualRow * cellSize + cellSize / 2,
      );

      paint.color = GameColors.forCellState(cells[i]);
      canvas.drawCircle(center, radius, paint);

      if (i == highlightedCell) {
        final highlightPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = GameColors.highlight
          ..strokeWidth = 2;
        canvas.drawCircle(center, radius + 2, highlightPaint);
      } else if (selectedCells.contains(i)) {
        final selectedPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = GameColors.selected
          ..strokeWidth = 2;
        canvas.drawCircle(center, radius + 2, selectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.highlightedCell != highlightedCell ||
        oldDelegate.selectedCells != selectedCells;
  }
}

/// Paints row labels on the left edge of the grid.
///
/// Bottom row = 1, top row = 381 (numbers increase upward).
class _RowLabelPainter extends CustomPainter {
  _RowLabelPainter({required this.cellSize, required this.color});

  final double cellSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final labelEvery = cellSize < 14 ? 4 : 1;

    for (var visualRow = 0;
        visualRow < NumberGrid.rows;
        visualRow += labelEvery) {
      final dataRow = (NumberGrid.rows - 1) - visualRow;
      final number = dataRow * NumberGrid.columns + 1;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            color: color,
            fontSize: cellSize * 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final y =
          visualRow * cellSize +
          (cellSize - textPainter.height) / 2;
      textPainter.paint(
        canvas,
        Offset(
          NumberGrid.rowLabelWidth - textPainter.width - 4,
          y,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RowLabelPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize || oldDelegate.color != color;
  }
}
