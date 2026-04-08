import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/view/widgets/widgets.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

/// The top-level page for a Chromix puzzle game session.
class ChromixPage extends StatelessWidget {
  /// Creates a [ChromixPage].
  const ChromixPage({required this.dailySeed, super.key});

  /// The daily seed for puzzle generation.
  final int dailySeed;

  @override
  Widget build(BuildContext context) {
    final dateKey = utcDateKey();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ChromixCubit(
            dailySeed: dailySeed,
            dateKey: dateKey,
            storageRepository:
                context.read<GameStorageRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ResultSharingCubit(
            identityRepository:
                context.read<NostrIdentityRepository>(),
            publishRepository:
                context.read<NostrPublishRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => CommunityStatsCubit(
            statsRepository:
                context.read<CommunityStatsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => LeaderboardCubit(
            statsRepository:
                context.read<CommunityStatsRepository>(),
            identityRepository:
                context.read<NostrIdentityRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ProfileCubit(
            profileRepository:
                context.read<NostrProfileRepository>(),
            identityRepository:
                context.read<NostrIdentityRepository>(),
          ),
        ),
      ],
      child: _ChromixView(dateKey: dateKey),
    );
  }
}

class _ChromixView extends StatefulWidget {
  const _ChromixView({required this.dateKey});

  final String dateKey;

  @override
  State<_ChromixView> createState() => _ChromixViewState();
}

class _ChromixViewState extends State<_ChromixView> {
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _showInstructionsIfFirstTime();

    // If already won on restore, show results immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<ChromixCubit>().state;
      if (state.status == ChromixStatus.won) {
        setState(() => _showResults = true);
      }
    });
  }

  void _showInstructionsIfFirstTime() {
    final repo = context.read<GameStorageRepository>();
    if (repo.hasSeenInstructions('chromix')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ChromixInstructionsDialog.show(context);
      await repo.markInstructionsSeen('chromix');
    });
  }

  void _persistStreak(BuildContext context) {
    const gameId = 'chromix';
    final repo = context.read<GameStorageRepository>();
    final streak = repo.getStreak(gameId);
    final updated = streak.recordCompletion(DateTime.now().toUtc());
    repo.saveStreak(gameId, updated);
  }

  void _fetchCommunityStats(BuildContext context) {
    context
        .read<CommunityStatsCubit>()
        .fetchStats('chromix:${widget.dateKey}');
  }

  void _onWin(BuildContext context) {
    _persistStreak(context);
    _fetchCommunityStats(context);

    WinCelebration.of(context)?.trigger(
      onShowResults: () {
        if (!mounted) return;
        setState(() => _showResults = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Chromix'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'New Puzzle',
              onPressed: () {
                WinCelebration.of(context)?.reset();
                context.read<ChromixCubit>().resetWithSeed(
                  DateTime.now().microsecondsSinceEpoch,
                );
                setState(() => _showResults = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                ChromixInstructionsDialog.show(context),
          ),
        ],
      ),
      body: WinCelebration(
        child: BlocConsumer<ChromixCubit, ChromixState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status &&
              curr.status == ChromixStatus.won,
          listener: (context, state) => _onWin(context),
          builder: (context, state) {
            if (state.status == ChromixStatus.loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ColorBar(
                        distribution: state.target,
                        label: 'Target',
                      ),
                      const SizedBox(height: 8),
                      BlocBuilder<ChromixCubit, ChromixState>(
                        buildWhen: (prev, curr) =>
                            prev.currentDistribution !=
                            curr.currentDistribution,
                        builder: (context, state) {
                          return ColorBar(
                            distribution:
                                state.currentDistribution,
                            label: 'Current',
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Expanded(child: ChromixGrid()),
                      const SizedBox(height: 12),
                      if (state.hasContiguityViolation)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Colors must be connected',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                          ),
                        ),
                      _UndoRow(state: state),
                    ],
                  ),
                ),
                if (state.status == ChromixStatus.won &&
                    _showResults)
                  Positioned.fill(
                    child: ChromixResultsOverlay(
                      state: state,
                      onViewPuzzle: () =>
                          setState(() => _showResults = false),
                    ),
                  ),
                if (state.status == ChromixStatus.won &&
                    !_showResults)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () =>
                          setState(() => _showResults = true),
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('Results'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UndoRow extends StatelessWidget {
  const _UndoRow({required this.state});

  final ChromixState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: state.moveHistory.isNotEmpty
              ? () => context.read<ChromixCubit>().undo()
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '${state.moveCount} moves · '
          '${state.undoCount} undos',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
