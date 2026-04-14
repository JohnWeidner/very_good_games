import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/core/view/widgets/star_rating.dart';
import 'package:very_good_games/games/cascade/cubit/cubit.dart';
import 'package:very_good_games/nostr/sharing/sharing.dart';
import 'package:very_good_games/nostr/sharing/view/community_stats_section.dart';
import 'package:very_good_games/nostr/sharing/view/result_sharing_listener.dart';
import 'package:very_good_games/nostr/sharing/view/share_result_button.dart';
import 'package:very_good_games/nostr/stats/stats.dart';

/// Results overlay displayed when the Cascade puzzle is solved.
class CascadeResultsOverlay extends StatelessWidget {
  /// Creates a [CascadeResultsOverlay].
  const CascadeResultsOverlay({
    required this.state,
    this.onViewPuzzle,
    super.key,
  });

  /// The final game state.
  final CascadeState state;

  /// Called when the user wants to view the puzzle board.
  final VoidCallback? onViewPuzzle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = state.score ?? 0;
    final stars = state.stars;

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
                      '$score points',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${state.attempts} '
                      '${state.attempts == 1 ? 'attempt' : 'attempts'}, '
                      '${formatElapsedTime(state.elapsedSeconds)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StarRating(stars: stars),
                    const SizedBox(height: 16),
                    ShareResultButton(onShare: () => _share(context)),
                    const CommunityStatsSection(),
                    LeaderboardSection(dTag: 'cascade:${utcDateKey()}'),
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
    final stars = state.stars;

    context.read<ResultSharingCubit>().share(
      eventBuilder: ({required pubKeyHex, required date}) =>
          EventBuilder.buildCascadeResult(
            pubKeyHex: pubKeyHex,
            score: score,
            stars: stars,
            attempts: state.attempts,
            elapsedSeconds: state.elapsedSeconds,
            date: date,
          ),
    );
  }
}
