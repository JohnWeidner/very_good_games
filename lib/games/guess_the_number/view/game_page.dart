import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/widgets.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/contact_list_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

/// The top-level page for a Guess the Number game session.
///
/// Creates the [GameCubit], manages the game timer, and composes
/// the header, grid, staged card, card tray, and results overlay.
class GamePage extends StatelessWidget {
  /// Creates a [GamePage].
  const GamePage({
    required this.targetNumber,
    required this.dailySeed,
    super.key,
  });

  /// The target number (1–400) for this game session.
  final int targetNumber;

  /// The daily seed, used for deterministic shotgun results.
  final int dailySeed;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final storage = context.read<GameStorageRepository>();
            return GameCubit.restore(
                  targetNumber: targetNumber,
                  dailySeed: dailySeed,
                  storageRepository: storage,
                ) ??
                GameCubit(
                  targetNumber: targetNumber,
                  dailySeed: dailySeed,
                  storageRepository: storage,
                );
          },
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
      child: const _GameView(),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView();

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  Timer? _timer;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => context.read<GameCubit>().tick(),
    );
    _showInstructionsIfFirstTime();

    // If already finished on restore, show results immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<GameCubit>().state;
      if (state.status == GameStatus.won || state.status == GameStatus.lost) {
        setState(() => _showResults = true);
      }
    });
  }

  void _showInstructionsIfFirstTime() {
    final repo = context.read<GameStorageRepository>();
    if (repo.hasSeenInstructions('guess_the_number')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await InstructionsDialog.show(context);
      await repo.markInstructionsSeen('guess_the_number');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persistStreak(BuildContext context) {
    const gameId = 'guess_the_number';
    final repo = context.read<GameStorageRepository>();
    final streak = repo.getStreak(gameId);
    final updated = streak.recordCompletion(DateTime.now().toUtc());
    repo.saveStreak(gameId, updated);
  }

  void _fetchCommunityStats(BuildContext context) {
    context.read<CommunityStatsCubit>().fetchStats(
      'guess-the-number:${utcDateKey()}',
    );
  }

  void _onGameOver(BuildContext context, GameState state) {
    _timer?.cancel();
    _fetchCommunityStats(context);

    if (state.status == GameStatus.won) {
      _persistStreak(context);
      WinCelebration.of(context)?.trigger(
        onShowResults: () {
          if (!mounted) return;
          setState(() => _showResults = true);
        },
      );
    } else {
      // Lost — show results immediately.
      setState(() => _showResults = true);
    }
  }

  /// Returns the set of cell indices for locked parameters,
  /// so the grid can draw persistent selection rings.
  Set<int> _selectedCells(GameState state) {
    if (state.firstParam == null) return const {};
    return {state.firstParam! - 1};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Guess the Number'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'New Game',
              onPressed: () {
                WinCelebration.of(context)?.reset();
                _timer?.cancel();
                _timer = Timer.periodic(
                  const Duration(seconds: 1),
                  (_) => context.read<GameCubit>().tick(),
                );
                context.read<GameCubit>().resetWithSeed(
                  DateTime.now().microsecondsSinceEpoch,
                );
                setState(() => _showResults = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => InstructionsDialog.show(context),
          ),
        ],
      ),
      body: WinCelebration(
        child: BlocConsumer<GameCubit, GameState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status &&
              (curr.status == GameStatus.won || curr.status == GameStatus.lost),
          listener: _onGameOver,
          builder: (context, state) {
            final cubit = context.read<GameCubit>();
            final isSelecting =
                state.status == GameStatus.selectingParam ||
                state.status == GameStatus.readyToConfirm;
            final isGameOver =
                state.status == GameStatus.won ||
                state.status == GameStatus.lost;

            return Stack(
              children: [
                Column(
                  children: [
                    // Score bar — always visible at the top.
                    ScoreBar(score: state.currentScore),
                    // Card tray — above the grid.
                    CardTray(
                      usedTypes: state.usedQuestionTypes,
                      onSelect: cubit.selectQuestion,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 28),
                        child: NumberGrid(
                          cells: state.cells,
                          highlightedCell: state.highlightedCell,
                          selectedCells: _selectedCells(state),
                          isSelecting: isSelecting,
                          onCellHighlighted: cubit.highlightCell,
                          onCellSelected: (_) => cubit.lockParam(),
                        ),
                      ),
                    ),
                    // Stats — below the grid.
                    GameHeader(state: state),
                    // Staged question card — below stats.
                    if (isSelecting)
                      QuestionCard(
                        state: state,
                        onConfirm: cubit.confirmQuestion,
                        onCancel: cubit.cancelQuestion,
                        onDigitSelected: cubit.setDigitParam,
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
                if (isGameOver && _showResults)
                  Positioned.fill(child: ResultsOverlay(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}
