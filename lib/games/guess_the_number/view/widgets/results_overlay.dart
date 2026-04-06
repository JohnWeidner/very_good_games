import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/daily_seed/date_key.dart';
import 'package:very_good_games/core/view/widgets/star_rating.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/event_builder.dart';
import 'package:very_good_games/nostr/sharing/view/community_stats_section.dart';
import 'package:very_good_games/nostr/sharing/view/result_sharing_listener.dart';
import 'package:very_good_games/nostr/sharing/view/share_result_button.dart';
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';

/// Overlay displayed when the game ends, showing score and stats.
class ResultsOverlay extends StatelessWidget {
  /// Creates a [ResultsOverlay].
  const ResultsOverlay({required this.state, super.key});

  /// The final game state.
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

    return ResultSharingListener(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
                      StarRating(
                        stars: ScoreCalculator.stars(state.score ?? 0),
                      ),
                      const SizedBox(height: 16),
                      ShareResultButton(onShare: () => _share(context)),
                      const CommunityStatsSection(),
                      LeaderboardSection(
                        dTag: 'guess-the-number:${utcDateKey()}',
                      ),
                    ] else ...[
                      Text(
                        'Score reached zero',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.questionCount} questions, $timeText',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const CommunityStatsSection(),
                      LeaderboardSection(
                        dTag: 'guess-the-number:${utcDateKey()}',
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
        ),
      ),
    );
  }

  void _share(BuildContext context) {
    final score = state.score ?? 0;
    final stars = ScoreCalculator.stars(score);
    final questionCount = state.questionCount;
    final elapsedSeconds = state.elapsedSeconds;

    context.read<ResultSharingCubit>().share(
      eventBuilder: ({required pubKeyHex, required date}) =>
          EventBuilder.buildGuessTheNumberResult(
            pubKeyHex: pubKeyHex,
            score: score,
            stars: stars,
            questionCount: questionCount,
            elapsedSeconds: elapsedSeconds,
            date: date,
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
