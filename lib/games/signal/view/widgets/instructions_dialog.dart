import 'package:flutter/material.dart';

/// A dialog explaining how to play Signal.
class SignalInstructionsDialog extends StatelessWidget {
  /// Creates a [SignalInstructionsDialog].
  const SignalInstructionsDialog({super.key});

  /// Shows the instructions dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SignalInstructionsDialog(),
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
              'Place walls on the grid so that every tower '
                  'reaches exactly the right number of cells.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Towers & Signals',
              'Each tower sends signals in 4 directions '
                  '(up, down, left, right). Signals travel through '
                  'empty cells but are blocked by walls and other towers.\n\n'
                  'The number on each tower is how many cells it '
                  'should reach.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'How to Play',
              '1. Tap a cell to place or remove a wall\n'
                  '2. Watch the tower counts update live\n'
                  '3. Green = satisfied, Red = too many signals',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Score',
              'You start with 500 points. Each move (wall toggle) '
                  'costs 20 points. Fewer moves = higher score!',
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
