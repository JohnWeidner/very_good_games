import 'package:flutter/material.dart';

/// A dialog explaining how to play Cascade.
class CascadeInstructionsDialog extends StatelessWidget {
  /// Creates a [CascadeInstructionsDialog].
  const CascadeInstructionsDialog({super.key});

  /// Shows the instructions dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CascadeInstructionsDialog(),
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
              'Route three numbered balls into their matching '
                  'target bins at the bottom of the board.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Setup',
              'Drag balls from the tray to the three drop slots. '
                  'Tap levers to flip their direction before dropping.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Levers',
              'When a ball hits a lever, it deflects in the '
                  "lever's direction, then the lever flips. "
                  'This changes the path for the next ball!',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Drop',
              'Press Drop to release all three balls in order. '
                  'Watch them cascade through the levers into the bins.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Score',
              'Fewer attempts = higher score! '
                  'First try = 3 stars.',
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
