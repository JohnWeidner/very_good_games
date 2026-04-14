import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';

/// Displays community stats (player count and average score) from Nostr.
///
/// Shared across all game results overlays.
class CommunityStatsSection extends StatelessWidget {
  /// Creates a [CommunityStatsSection].
  const CommunityStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityStatsCubit, CommunityStatsState>(
      builder: (context, state) {
        if (state.status != CommunityStatsStatus.loaded ||
            state.stats == null) {
          return const SizedBox.shrink();
        }

        final stats = state.stats!;
        final timeText = stats.avgTime != null
            ? ', ~${formatElapsedTime(stats.avgTime!.round())} avg time'
            : '';
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '~${stats.playerCount} players, '
            '~${stats.avgScore.toStringAsFixed(0)} avg score'
            '$timeText',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
