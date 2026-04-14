import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/cubit/cubit.dart';
import 'package:very_good_games/games/cascade/view/widgets/widgets.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/sharing/sharing.dart';
import 'package:very_good_games/nostr/stats/stats.dart';

/// The top-level page for a Cascade puzzle game session.
class CascadePage extends StatelessWidget {
  /// Creates a [CascadePage].
  const CascadePage({required this.dailySeed, super.key});

  /// The daily seed for puzzle generation.
  final int dailySeed;

  @override
  Widget build(BuildContext context) {
    final dateKey = utcDateKey();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => CascadeCubit(
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
        BlocProvider(
          create: (context) => ContactListCubit(
            contactListRepository: context.read<ContactListRepository>(),
            identityRepository: context.read<NostrIdentityRepository>(),
          ),
        ),
      ],
      child: _CascadeView(dateKey: dateKey),
    );
  }
}

class _CascadeView extends StatefulWidget {
  const _CascadeView({required this.dateKey});

  final String dateKey;

  @override
  State<_CascadeView> createState() => _CascadeViewState();
}

class _CascadeViewState extends State<_CascadeView>
    with WidgetsBindingObserver {
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showInstructionsIfFirstTime();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<CascadeCubit>().state;
      if (state.status == CascadeStatus.won) {
        setState(() => _showResults = true);
      }
    });
  }

  void _showInstructionsIfFirstTime() {
    final repo = context.read<GameStorageRepository>();
    if (repo.hasSeenInstructions('cascade')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await CascadeInstructionsDialog.show(context);
      await repo.markInstructionsSeen('cascade');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<CascadeCubit>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      cubit.pauseTimer();
    } else if (state == AppLifecycleState.resumed) {
      cubit.resumeTimer();
    }
  }

  void _persistStreak(BuildContext context) {
    const gameId = 'cascade';
    final repo = context.read<GameStorageRepository>();
    final streak = repo.getStreak(gameId);
    final updated = streak.recordCompletion(DateTime.now().toUtc());
    repo.saveStreak(gameId, updated);
  }

  void _fetchCommunityStats(BuildContext context) {
    context.read<CommunityStatsCubit>().fetchStats('cascade:${widget.dateKey}');
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
        title: const Text('Cascade'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'New Puzzle',
              onPressed: () {
                WinCelebration.of(context)?.reset();
                context.read<CascadeCubit>().resetWithSeed(
                  DateTime.now().microsecondsSinceEpoch,
                );
                setState(() => _showResults = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => CascadeInstructionsDialog.show(context),
          ),
        ],
      ),
      body: WinCelebration(
        child: BlocConsumer<CascadeCubit, CascadeState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status && curr.status == CascadeStatus.won,
          listener: (context, state) => _onWin(context),
          builder: (context, state) {
            if (state.status == CascadeStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      BallTray(
                        slotAssignments: state.slotAssignments,
                        onBallAssigned: (ball, slot) =>
                            context.read<CascadeCubit>().assignBall(ball, slot),
                        enabled: state.status == CascadeStatus.configuring,
                      ),
                      const Expanded(child: CascadeBoardWidget()),
                      const SizedBox(height: 12),
                      _ActionRow(state: state),
                    ],
                  ),
                ),
                if (state.status == CascadeStatus.won && _showResults)
                  Positioned.fill(
                    child: CascadeResultsOverlay(
                      state: state,
                      onViewPuzzle: () => setState(() => _showResults = false),
                    ),
                  ),
                if (state.status == CascadeStatus.won && !_showResults)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () => setState(() => _showResults = true),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state});

  final CascadeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.status == CascadeStatus.configuring)
          FilledButton.icon(
            onPressed: state.allBallsAssigned
                ? () => context.read<CascadeCubit>().drop()
                : null,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('DROP'),
          ),
        if (state.status == CascadeStatus.failed)
          OutlinedButton.icon(
            onPressed: () => context.read<CascadeCubit>().reset(),
            icon: const Icon(Icons.refresh),
            label: const Text('RESET'),
          ),
        if (state.attempts > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              label:
                  '${state.elapsedSeconds ~/ 60} minutes and '
                  '${state.elapsedSeconds % 60} seconds elapsed',
              child: Text(
                '${state.attempts} '
                '${state.attempts == 1 ? 'attempt' : 'attempts'}'
                ' · ${formatElapsedTime(state.elapsedSeconds)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
