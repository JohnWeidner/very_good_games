import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';

/// Displays the timer, question count, remaining cells,
/// and the last question result feedback.
class GameHeader extends StatelessWidget {
  /// Creates a [GameHeader].
  const GameHeader({required this.state, super.key});

  /// The current game state.
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = state.elapsedSeconds ~/ 60;
    final seconds = state.elapsedSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Stats row: timer, guesses, remaining.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                icon: Icons.timer_outlined,
                label: timeText,
              ),
              _StatChip(
                icon: Icons.help_outline,
                label: '${state.questionCount} asked',
              ),
              _StatChip(
                icon: Icons.grid_on,
                label: '${state.remainingCount} left',
              ),
            ],
          ),
          // Last question result feedback.
          if (state.lastResult != null) ...[
            const SizedBox(height: 4),
            Text(
              state.lastResult!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurface),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
