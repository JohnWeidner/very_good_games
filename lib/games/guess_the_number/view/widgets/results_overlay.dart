import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';

/// Overlay displayed when the player wins, showing score and stats.
class ResultsOverlay extends StatelessWidget {
  /// Creates a [ResultsOverlay].
  const ResultsOverlay({required this.state, super.key});

  /// The final game state (must have [GameStatus.won]).
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = state.elapsedSeconds ~/ 60;
    final seconds = state.elapsedSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    final isWin = state.status == GameStatus.won;

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isWin ? 'You found it!' : "Time's up!",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWin ? null : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The number was ${state.targetNumber}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                if (isWin) ...[
                  // Score.
                  Text(
                    '${state.score}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'points',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BreakdownRow(
                    label: 'Questions',
                    value: '${state.questionCount}',
                    penalty: '-${state.questionCount * 50}',
                  ),
                  _BreakdownRow(
                    label: 'Time',
                    value: timeText,
                    penalty: '-${state.elapsedSeconds * 2}',
                  ),
                  const SizedBox(height: 24),
                  _StarRating(score: state.score ?? 0),
                ] else ...[
                  Text(
                    'Score reached zero',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.questionCount} questions, $timeText',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Hub'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.penalty,
  });

  final String label;
  final String value;
  final String penalty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              penalty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final stars = score >= 450
        ? 3
        : score >= 250
            ? 2
            : 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? Icons.star : Icons.star_border,
          color: const Color(0xFFFFD600),
          size: 36,
        );
      }),
    );
  }
}
