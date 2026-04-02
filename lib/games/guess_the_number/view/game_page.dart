import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/widgets.dart';

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
    return BlocProvider(
      create: (_) => GameCubit(
        targetNumber: targetNumber,
        dailySeed: dailySeed,
      ),
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
  static const _seenInstructionsKey = 'guess_the_number_seen_instructions';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => context.read<GameCubit>().tick(),
    );
    _showInstructionsIfFirstTime();
  }

  Future<void> _showInstructionsIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenInstructionsKey) ?? false) return;
    if (!mounted) return;
    await InstructionsDialog.show(context);
    await prefs.setBool(_seenInstructionsKey, true);
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
        title: const Text('Guess the Number'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => InstructionsDialog.show(context),
          ),
        ],
      ),
      body: BlocConsumer<GameCubit, GameState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            (curr.status == GameStatus.won ||
                curr.status == GameStatus.lost),
        listener: (context, state) {
          _timer?.cancel();
          if (state.status == GameStatus.won) {
            _persistStreak(context);
          }
        },
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
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 28,
                      ),
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
              if (isGameOver)
                Positioned.fill(
                  child: ResultsOverlay(state: state),
                ),
            ],
          );
        },
      ),
    );
  }
}
