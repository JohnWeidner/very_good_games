import 'package:flutter/material.dart';

/// A dialog explaining how to play Guess the Number.
class InstructionsDialog extends StatelessWidget {
  /// Creates an [InstructionsDialog].
  const InstructionsDialog({super.key});

  /// Shows the instructions dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const InstructionsDialog(),
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
              'A number between 1 and 400 is hidden in the grid. '
                  'Eliminate numbers by asking questions until only '
                  'one remains.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'How to Play',
              '1. Tap a question card at the top\n'
                  '2. Pick a number on the grid (use the magnifier)\n'
                  '3. Tap "Play" to ask the question\n'
                  '4. Watch numbers get eliminated!',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Question Cards',
              '• Each card can only be used once '
                  '(except "= N" which is repeatable)\n'
                  '• "< N" — is the number less than N?\n'
                  '• "odd?" — is the number odd?\n'
                  '• "÷ N" — is it divisible by N?\n'
                  '• "prime?" — is it a prime number?\n'
                  '• "ends in" — pick a digit (0-9)\n'
                  '• "= N" — guess the exact number\n'
                  '• "shotgun" — picks 50 random numbers. '
                  'If the target is among them, everything else '
                  'is eliminated!\n'
                  '• "grenade" — eliminates 20 nearby numbers',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Score',
              'You start with 600 points. Each question costs 50 '
                  'points and each second costs 2 points. '
                  'If your score hits zero, you lose!',
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
