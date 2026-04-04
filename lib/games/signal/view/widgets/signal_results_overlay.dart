import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/identity/view/identity_explainer_flow.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_page.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/event_builder.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';

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

    return BlocListener<ResultSharingCubit, ResultSharingState>(
      listener: (context, sharingState) {
        if (sharingState.status == ResultSharingStatus.checkingIdentity) {
          _launchIdentitySetup(context);
        } else if (sharingState.status == ResultSharingStatus.success) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Result shared! Remember to back up your key '
                  'in Settings.',
                ),
              ),
            );
        } else if (sharingState.status == ResultSharingStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sharingState.errorMessage ?? 'Could not share your result.',
              ),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => context.read<ResultSharingCubit>().publish(),
              ),
            ),
          );
        }
      },
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
                      '${state.moveCount} moves',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            i < stars ? Icons.star : Icons.star_border,
                            color: i < stars
                                ? Colors.amber
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                            size: 36,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ShareButton(state: state),
                    const _CommunityStatsSection(),
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

  Future<void> _launchIdentitySetup(BuildContext context) async {
    final proceed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const IdentityExplainerFlow(),
      ),
    );

    if ((proceed ?? false) && context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => NostrIdentityCubit(
              identityRepository: context.read<NostrIdentityRepository>(),
              deletionRepository: context.read<NostrDeletionRepository>(),
            ),
            child: const IdentitySetupPage(),
          ),
        ),
      );

      if (context.mounted) {
        await context.read<ResultSharingCubit>().publish();
      }
    }
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.state});

  final SignalState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultSharingCubit, ResultSharingState>(
      builder: (context, sharingState) {
        return switch (sharingState.status) {
          ResultSharingStatus.success => FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check),
            label: const Text('Shared'),
          ),
          ResultSharingStatus.publishing ||
          ResultSharingStatus.checkingIdentity => FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: const Text('Sharing...'),
          ),
          _ => FilledButton.icon(
            onPressed: () => _share(context),
            icon: const Icon(Icons.share),
            label: const Text('Share to Nostr'),
          ),
        };
      },
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
            date: date,
          ),
    );
  }
}

class _CommunityStatsSection extends StatelessWidget {
  const _CommunityStatsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityStatsCubit, CommunityStatsState>(
      builder: (context, state) {
        if (state.status != CommunityStatsStatus.loaded ||
            state.stats == null) {
          return const SizedBox.shrink();
        }

        final stats = state.stats!;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '~${stats.playerCount} players, '
            '~${stats.avgScore.toStringAsFixed(0)} avg score',
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
