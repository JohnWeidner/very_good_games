import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/identity/view/identity_explainer_flow.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_page.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';

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
                    _StarRating(score: state.score ?? 0),
                    const SizedBox(height: 16),
                    _ShareButton(state: state),
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
            ),
            child: const IdentitySetupPage(),
          ),
        ),
      );

      // After identity setup, resume the publish flow.
      if (context.mounted) {
        await context.read<ResultSharingCubit>().publish();
      }
    }
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.state});

  final GameState state;

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
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    context.read<ResultSharingCubit>().share(
      score: state.score ?? 0,
      stars: ScoreCalculator.stars(state.score ?? 0),
      questionCount: state.questionCount,
      elapsedSeconds: state.elapsedSeconds,
      date: date,
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
    final stars = ScoreCalculator.stars(score);
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
