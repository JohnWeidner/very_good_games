import 'package:flutter/material.dart';

/// A dialog explaining how to play Chromix.
class ChromixInstructionsDialog extends StatelessWidget {
  /// Creates a [ChromixInstructionsDialog].
  const ChromixInstructionsDialog({super.key});

  /// Shows the instructions dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ChromixInstructionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('How to Play'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _section(
              theme,
              'Goal',
              'Fill the grid so the color distribution '
                  'matches the target bar, with each color '
                  'forming one connected group.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Drag to Spread Color',
              'Drag a primary colored cell (R, Y, B) to an adjacent '
                  'empty cell to spread that color.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Color Mixing (RYB)',
              'Drag a primary onto a different primary '
                  'to mix:\n'
                  'Red + Yellow = Orange\n'
                  'Red + Blue = Purple\n'
                  'Yellow + Blue = Green\n\n'
                  'Hold longer to overpower — the mixed '
                  'color becomes the dragged color.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Contiguity Rule',
              'Each color must form one connected group '
                  '(orthogonally adjacent). Disconnected '
                  'groups of the same color will not count '
                  'as a win.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Score',
              'Your score is moves + undos. '
                  'Fewer actions = more stars!',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it!'),
        ),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
