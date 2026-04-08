import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/view/widgets/widgets.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

/// The top-level page for a Signal puzzle game session.
class SignalPage extends StatelessWidget {
  /// Creates a [SignalPage].
  const SignalPage({required this.dailySeed, super.key});

  /// The daily seed for puzzle generation.
  final int dailySeed;

  @override
  Widget build(BuildContext context) {
    final dateKey = utcDateKey();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SignalCubit(
            dailySeed: dailySeed,
            dateKey: dateKey,
            storageRepository: context.read<GameStorageRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ResultSharingCubit(
            identityRepository: context.read<NostrIdentityRepository>(),
            publishRepository: context.read<NostrPublishRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => CommunityStatsCubit(
            statsRepository: context.read<CommunityStatsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => LeaderboardCubit(
            statsRepository: context.read<CommunityStatsRepository>(),
            identityRepository: context.read<NostrIdentityRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ProfileCubit(
            profileRepository: context.read<NostrProfileRepository>(),
            identityRepository: context.read<NostrIdentityRepository>(),
          ),
        ),
      ],
      child: _SignalView(dateKey: dateKey),
    );
  }
}

class _SignalView extends StatefulWidget {
  const _SignalView({required this.dateKey});

  final String dateKey;

  @override
  State<_SignalView> createState() => _SignalViewState();
}

class _SignalViewState extends State<_SignalView> {
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _showInstructionsIfFirstTime();

    // If already won on restore, show results immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SignalCubit>().state;
      if (state.status == SignalStatus.won) {
        setState(() => _showResults = true);
      }
    });
  }

  void _showInstructionsIfFirstTime() {
    final repo = context.read<GameStorageRepository>();
    if (repo.hasSeenInstructions('signal')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await SignalInstructionsDialog.show(context);
      await repo.markInstructionsSeen('signal');
    });
  }

  void _persistStreak(BuildContext context) {
    const gameId = 'signal';
    final repo = context.read<GameStorageRepository>();
    final streak = repo.getStreak(gameId);
    final updated = streak.recordCompletion(DateTime.now().toUtc());
    repo.saveStreak(gameId, updated);
  }

  void _fetchCommunityStats(BuildContext context) {
    context.read<CommunityStatsCubit>().fetchStats('signal:${widget.dateKey}');
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
        title: const Text('Signal'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'New Puzzle',
              onPressed: () {
                WinCelebration.of(context)?.reset();
                context.read<SignalCubit>().resetWithSeed(
                  DateTime.now().microsecondsSinceEpoch,
                );
                setState(() => _showResults = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => SignalInstructionsDialog.show(context),
          ),
        ],
      ),
      body: WinCelebration(
        child: BlocConsumer<SignalCubit, SignalState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status && curr.status == SignalStatus.won,
          listener: (context, state) => _onWin(context),
          builder: (context, state) {
            if (state.status == SignalStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Walls: ${state.wallCount} / '
                        '${state.solutionWallCount}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${state.moveCount} moves',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 16),
                      const Expanded(child: SignalGrid()),
                    ],
                  ),
                ),
                if (state.status == SignalStatus.won && _showResults)
                  Positioned.fill(
                    child: SignalResultsOverlay(
                      state: state,
                      onViewPuzzle: () =>
                          setState(() => _showResults = false),
                    ),
                  ),
                if (state.status == SignalStatus.won && !_showResults)
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
