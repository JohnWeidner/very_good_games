import 'dart:math';

import 'package:flutter/material.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/theme/theme.dart';

/// A pie chart showing color distribution for Chromix.
///
/// Use [ColorPieChart.fromDistribution] for the target (contiguous
/// by construction). Use [ColorPieChart.fromGrid] for the current
/// state, which shows each disconnected blob as a separate slice
/// and includes empty cells as gray.
class ColorPieChart extends StatelessWidget {
  /// Creates a [ColorPieChart] from pre-built slices.
  const ColorPieChart._({
    required this.slices,
    required this.label,
    super.key,
  });

  /// Creates a pie chart from a simple color distribution.
  ///
  /// Each color gets one slice. No empty-cell slice.
  factory ColorPieChart.fromDistribution({
    required Map<ChromixColor, int> distribution,
    required String label,
    Key? key,
  }) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final slices = <PieSlice>[];
    if (total > 0) {
      for (final color in _colorOrder) {
        final count = distribution[color] ?? 0;
        if (count > 0) {
          slices.add(
            PieSlice(
              count: count,
              fraction: count / total,
              color: _colorFor(color),
              label: '$count',
              textColor: color == ChromixColor.yellow
                  ? Colors.black
                  : Colors.white,
            ),
          );
        }
      }
    }
    return ColorPieChart._(slices: slices, label: label, key: key);
  }

  /// Creates a pie chart from a grid, showing each connected blob
  /// as a separate slice and empty cells as gray.
  factory ColorPieChart.fromGrid({
    required ChromixGrid grid,
    required String label,
    Key? key,
  }) {
    // Count total non-blocker cells for fraction calculation.
    final nonBlockerCount = grid.nonBlockerCount;
    if (nonBlockerCount == 0) {
      return ColorPieChart._(slices: const [], label: label, key: key);
    }

    // Flood-fill to find blobs, ordered by _colorOrder then by size.
    const size = ChromixGrid.size;
    final visited = <int>{};
    final blobs = <(ChromixColor, int)>[]; // (color, cellCount)

    // Process colors in order for consistent slice ordering.
    for (final targetColor in _colorOrder) {
      for (var i = 0; i < grid.cells.length; i++) {
        if (visited.contains(i)) continue;
        final cell = grid.cells[i];
        if (cell is! ColorCell || cell.color != targetColor) continue;

        // Flood-fill this blob.
        var count = 0;
        final queue = [i];
        visited.add(i);

        while (queue.isNotEmpty) {
          final current = queue.removeLast();
          count++;
          final r = current ~/ size;
          final c = current % size;
          for (final n in [
            if (r > 0) (r - 1) * size + c,
            if (r < size - 1) (r + 1) * size + c,
            if (c > 0) r * size + (c - 1),
            if (c < size - 1) r * size + (c + 1),
          ]) {
            if (visited.contains(n)) continue;
            final nc = grid.cells[n];
            if (nc is ColorCell && nc.color == targetColor) {
              visited.add(n);
              queue.add(n);
            }
          }
        }

        blobs.add((targetColor, count));
      }
    }

    // Count empty cells.
    var emptyCount = 0;
    for (final cell in grid.cells) {
      if (cell is EmptyCell) emptyCount++;
    }

    final slices = <PieSlice>[];
    for (final (color, count) in blobs) {
      slices.add(
        PieSlice(
          count: count,
          fraction: count / nonBlockerCount,
          color: _colorFor(color),
          label: '$count',
          textColor: color == ChromixColor.yellow
              ? Colors.black
              : Colors.white,
        ),
      );
    }
    if (emptyCount > 0) {
      slices.add(
        PieSlice(
          count: emptyCount,
          fraction: emptyCount / nonBlockerCount,
          color: ChromixColors.empty,
          label: '$emptyCount',
          textColor: Colors.black54,
        ),
      );
    }

    return ColorPieChart._(slices: slices, label: label, key: key);
  }

  /// The slices to render.
  final List<PieSlice> slices;

  /// Label displayed below the chart.
  final String label;

  static const _colorOrder = [
    ChromixColor.red,
    ChromixColor.yellow,
    ChromixColor.blue,
    ChromixColor.orange,
    ChromixColor.green,
    ChromixColor.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: slices.isEmpty
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: ChromixColors.empty,
                    shape: BoxShape.circle,
                  ),
                )
              : CustomPaint(
                  painter: _PiePainter(slices: slices),
                ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
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

/// A single slice of a [ColorPieChart].
class PieSlice {
  /// Creates a [PieSlice].
  const PieSlice({
    required this.count,
    required this.fraction,
    required this.color,
    required this.label,
    required this.textColor,
  });

  /// The number of cells this slice represents.
  final int count;

  /// The fraction of the total (0.0–1.0).
  final double fraction;

  /// The fill color.
  final Color color;

  /// The text label (typically the count).
  final String label;

  /// The label text color.
  final Color textColor;
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices});

  final List<PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;

    var startAngle = -pi / 2; // Start from top.

    for (final slice in slices) {
      final sweepAngle = slice.fraction * 2 * pi;
      paint.color = slice.color;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw label at the midpoint of the arc.
      if (slice.fraction >= 0.05) {
        final midAngle = startAngle + sweepAngle / 2;
        final labelRadius = radius * 0.6;
        final labelOffset = Offset(
          center.dx + labelRadius * cos(midAngle),
          center.dy + labelRadius * sin(midAngle),
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: slice.label,
            style: TextStyle(
              color: slice.textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            labelOffset.dx - textPainter.width / 2,
            labelOffset.dy - textPainter.height / 2,
          ),
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      slices != oldDelegate.slices;
}
