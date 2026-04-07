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
                  'matches the target bar.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Color Mixing (RYB)',
              'Red + Yellow = Orange\n'
                  'Red + Blue = Purple\n'
                  'Yellow + Blue = Green',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'How to Play',
              '1. Select a primary color (R, Y, or B)\n'
                  '2. Tap an empty cell to place it\n'
                  '3. Tap a primary cell with a different '
                  'primary to mix\n'
                  '4. Use undo to reverse mistakes\n'
                  '5. Match the target color bar to win!',
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
