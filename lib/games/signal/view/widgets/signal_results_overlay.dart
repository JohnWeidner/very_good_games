import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/core/view/widgets/star_rating.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/event_builder.dart';
import 'package:very_good_games/nostr/sharing/view/community_stats_section.dart';
import 'package:very_good_games/nostr/sharing/view/result_sharing_listener.dart';
import 'package:very_good_games/nostr/sharing/view/share_result_button.dart';
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';

/// Results overlay displayed when the Signal puzzle is solved.
class SignalResultsOverlay extends StatelessWidget {
  /// Creates a [SignalResultsOverlay].
  const SignalResultsOverlay({
    required this.state,
    this.onViewPuzzle,
    super.key,
  });

  /// The final game state.
  final SignalState state;

  /// Called when the user wants to dismiss the overlay to view the puzzle.
  final VoidCallback? onViewPuzzle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = state.score ?? 0;
    final stars = SignalScoreCalculator.stars(score);

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
                      'Puzzle Solved!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$score',
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
                    Text(
                      '${state.moveCount} moves, '
                      '${formatElapsedTime(state.elapsedSeconds)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    StarRating(stars: stars),
                    const SizedBox(height: 16),
                    ShareResultButton(onShare: () => _share(context)),
                    const CommunityStatsSection(),
                    LeaderboardSection(dTag: 'signal:${utcDateKey()}'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (onViewPuzzle != null)
                          OutlinedButton(
                            onPressed: onViewPuzzle,
                            child: const Text('View Puzzle'),
                          ),
                        if (onViewPuzzle != null) const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Back to Hub'),
                        ),
                      ],
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
    final stars = SignalScoreCalculator.stars(score);
    final moveCount = state.moveCount;

    context.read<ResultSharingCubit>().share(
      eventBuilder: ({required pubKeyHex, required date}) =>
          EventBuilder.buildSignalResult(
            pubKeyHex: pubKeyHex,
            score: score,
            stars: stars,
            moveCount: moveCount,
            elapsedSeconds: state.elapsedSeconds,
            date: date,
          ),
    );
  }
}
