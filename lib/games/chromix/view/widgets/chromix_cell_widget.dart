import 'package:flutter/material.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/theme/theme.dart';

/// Renders a single cell in the Chromix grid.
class ChromixCellWidget extends StatelessWidget {
  /// Creates a [ChromixCellWidget].
  const ChromixCellWidget({
    required this.cell,
    required this.onTap,
    super.key,
  });

  /// The cell to render.
  final ChromixCell cell;

  /// Called when the cell is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: _border,
        ),
        child: Center(child: _label(context)),
      ),
    );
  }

  Color get _backgroundColor => switch (cell) {
    EmptyCell() => ChromixColors.empty,
    BlockerCell() => ChromixColors.blocker,
    ColorCell(color: final c) => _colorFor(c),
  };

  Border? get _border => switch (cell) {
    ColorCell(isPreFilled: true) => Border.all(
      color: Colors.black26,
      width: 2,
    ),
    _ => null,
  };

  Widget? _label(BuildContext context) => switch (cell) {
    ColorCell(color: final c) => Text(
      _letterFor(c),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    _ => null,
  };

  static Color _colorFor(ChromixColor color) => switch (color) {
    ChromixColor.red => ChromixColors.red,
    ChromixColor.yellow => ChromixColors.yellow,
    ChromixColor.blue => ChromixColors.blue,
    ChromixColor.orange => ChromixColors.orange,
    ChromixColor.green => ChromixColors.green,
    ChromixColor.purple => ChromixColors.purple,
  };

  static String _letterFor(ChromixColor color) => switch (color) {
    ChromixColor.red => 'R',
    ChromixColor.yellow => 'Y',
    ChromixColor.blue => 'B',
    ChromixColor.orange => 'O',
    ChromixColor.green => 'G',
    ChromixColor.purple => 'P',
  };
}
