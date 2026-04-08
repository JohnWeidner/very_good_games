import 'package:flutter/material.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/theme/theme.dart';

/// A proportional horizontal bar showing color distribution.
///
/// Reusable for both target (static) and current (live) bars.
class ColorBar extends StatelessWidget {
  /// Creates a [ColorBar].
  const ColorBar({
    required this.distribution,
    required this.label,
    super.key,
  });

  /// Color counts to display.
  final Map<ChromixColor, int> distribution;

  /// Label displayed above the bar (e.g. "Target", "Current").
  final String label;

  /// Ordered list of colors for consistent rendering.
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
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: ChromixColors.empty,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                for (final color in _colorOrder)
                  if ((distribution[color] ?? 0) > 0)
                    Expanded(
                      flex: distribution[color]!,
                      child: Container(
                        color: _colorFor(color),
                        alignment: Alignment.center,
                        child: FittedBox(
                          child: Text(
                            '${distribution[color]}',
                            style: TextStyle(
                              color: color == ChromixColor.yellow
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
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
