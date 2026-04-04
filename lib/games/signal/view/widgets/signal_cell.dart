import 'package:flutter/material.dart';
import 'package:very_good_games/games/signal/models/models.dart';
import 'package:very_good_games/games/signal/theme/signal_colors.dart';

/// Renders a single cell in the Signal puzzle grid.
class SignalCell extends StatelessWidget {
  /// Creates a [SignalCell].
  const SignalCell({
    required this.cell,
    this.signalCount,
    this.isSignaled = false,
    super.key,
  });

  /// The cell data to render.
  final Cell cell;

  /// Current signal count for tower cells (null for non-tower cells).
  final int? signalCount;

  /// Whether this cell is in a signal ray path.
  final bool isSignaled;

  @override
  Widget build(BuildContext context) {
    return switch (cell) {
      EmptyCell() => _EmptyCell(isSignaled: isSignaled),
      WallCell() => const _WallCell(),
      Tower(:final targetCount) => _TowerCell(
        targetCount: targetCount,
        signalCount: signalCount ?? 0,
      ),
    };
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell({required this.isSignaled});

  final bool isSignaled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSignaled
            ? SignalColors.signalRay.withValues(alpha: 0.15)
            : SignalColors.empty,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
    );
  }
}

class _WallCell extends StatelessWidget {
  const _WallCell();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignalColors.wall,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _TowerCell extends StatelessWidget {
  const _TowerCell({required this.targetCount, required this.signalCount});

  final int targetCount;
  final int signalCount;

  bool get _isSatisfied => signalCount == targetCount;
  bool get _isOver => signalCount > targetCount;

  String get _statusLabel {
    if (_isSatisfied) return 'satisfied';
    if (_isOver) return 'over';
    return 'under';
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData? statusIcon;

    if (_isSatisfied) {
      bgColor = SignalColors.satisfied.withValues(alpha: 0.15);
      borderColor = SignalColors.satisfied;
      textColor = SignalColors.satisfied;
      statusIcon = Icons.check_circle;
    } else if (_isOver) {
      bgColor = SignalColors.conflict.withValues(alpha: 0.1);
      borderColor = SignalColors.conflict;
      textColor = SignalColors.conflict;
      statusIcon = Icons.warning;
    } else {
      bgColor = SignalColors.towerBackground;
      borderColor = SignalColors.unsatisfied;
      textColor = Colors.black87;
      statusIcon = null;
    }

    return Semantics(
      label:
          'Tower, target $targetCount, '
          'current $signalCount, $_statusLabel',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$targetCount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (statusIcon != null)
                Icon(statusIcon, size: 14, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }
}
