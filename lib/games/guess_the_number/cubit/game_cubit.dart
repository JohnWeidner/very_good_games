import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

part 'game_state.dart';

/// Manages the state of a single Guess the Number game session.
///
/// The turn flow is:
/// 1. Player taps a card in the tray → [selectQuestion]
/// 2. Player slides on the grid to pick a number → [highlightCell]
/// 3. Player lifts finger to lock the param → [lockParam]
/// 4. Player taps "Play" → [confirmQuestion]
///
/// For no-parameter questions, [selectQuestion] goes straight to
/// [GameStatus.readyToConfirm].
class GameCubit extends Cubit<GameState> {
  /// Creates a [GameCubit] with the given [targetNumber].
  ///
  /// The target must be between 1 and 400 inclusive.
  /// Provide [random] to override shotgun randomness in tests.
  /// Provide [dailySeed] for deterministic daily shotgun results.
  /// Provide [storageRepository] to enable session persistence.
  GameCubit({
    required int targetNumber,
    Random? random,
    int? dailySeed,
    GameStorageRepository? storageRepository,
  }) : _random = random,
       _dailySeed = dailySeed,
       _storageRepository = storageRepository,
       assert(
         targetNumber >= 1 && targetNumber <= 400,
         'Target must be between 1 and 400',
       ),
       super(
         GameState(
           cells: List.filled(400, CellState.possible),
           targetNumber: targetNumber,
         ),
       );

  /// Creates a [GameCubit] restored from a saved session.
  GameCubit._restored({
    required GameState restoredState,
    Random? random,
    int? dailySeed,
    GameStorageRepository? storageRepository,
  }) : _random = random,
       _dailySeed = dailySeed,
       _storageRepository = storageRepository,
       super(restoredState);

  /// Attempts to restore a [GameCubit] from a saved session.
  ///
  /// Returns `null` if no saved session exists or the saved session's
  /// daily seed doesn't match [dailySeed] (i.e. it's from a different day).
  static GameCubit? restore({
    required int targetNumber,
    required GameStorageRepository storageRepository,
    int? dailySeed,
  }) {
    final session = storageRepository.getSession(_gameId);
    if (session == null) return null;

    final savedSeed = session['dailySeed'] as int?;
    if (savedSeed != dailySeed) {
      // Stale session from a different day — discard it.
      unawaited(storageRepository.saveSession(_gameId, null));
      return null;
    }

    try {
      final cellInts = (session['cells'] as List<dynamic>).cast<int>();
      final cells = cellInts.map((i) => CellState.values[i]).toList();
      final usedTypes = (session['usedQuestionTypes'] as List<dynamic>)
          .cast<int>()
          .map((i) => QuestionType.values[i])
          .toSet();

      final restoredState = GameState(
        cells: cells,
        targetNumber: targetNumber,
        usedQuestionTypes: usedTypes,
        questionCount: session['questionCount'] as int,
        elapsedSeconds: session['elapsedSeconds'] as int,
        timerStarted: session['timerStarted'] as bool,
      );

      return GameCubit._restored(
        restoredState: restoredState,
        dailySeed: dailySeed,
        storageRepository: storageRepository,
      );
    } on Object {
      // Corrupted session data — discard and start fresh.
      unawaited(storageRepository.saveSession(_gameId, null));
      return null;
    }
  }

  static const _gameId = 'guess_the_number';

  /// Resets with a new random target number. For playtesting only.
  void resetWithSeed(int seed) {
    final target = (seed.abs() % 400) + 1;
    emit(
      GameState(
        cells: List.filled(400, CellState.possible),
        targetNumber: target,
      ),
    );
  }

  final Random? _random;
  final int? _dailySeed;
  final GameStorageRepository? _storageRepository;

  /// Returns the [Random] for shotgun, seeded deterministically
  /// from the daily seed and current question count so that two
  /// players making the same moves get identical results.
  Random _shotgunRandom() {
    if (_random != null) return _random;
    if (_dailySeed != null) {
      return Random(_dailySeed ^ state.questionCount);
    }
    return Random();
  }

  /// Stages a question card for the given [type].
  ///
  /// If the question requires no parameters, transitions directly
  /// to [GameStatus.readyToConfirm]. Otherwise enters param selection.
  void selectQuestion(QuestionType type) {
    if (state.status == GameStatus.won) return;
    if (state.status == GameStatus.lost) return;
    if (state.usedQuestionTypes.contains(type)) return;

    final newStatus = type.paramCount == 0
        ? GameStatus.readyToConfirm
        : GameStatus.selectingParam;

    emit(
      state.copyWith(
        status: newStatus,
        activeQuestionType: () => type,
        highlightedCell: () => null,
        firstParam: () => null,
        lastResult: () => null,
      ),
    );
  }

  /// Cancels the currently staged question and returns to the tray.
  void cancelQuestion() {
    if (state.status == GameStatus.won) return;
    if (state.status == GameStatus.lost) return;
    if (state.activeQuestionType == null) return;

    emit(
      state.copyWith(
        status: GameStatus.playing,
        activeQuestionType: () => null,
        highlightedCell: () => null,
        firstParam: () => null,
      ),
    );
  }

  /// Updates the currently highlighted cell as the player drags.
  void highlightCell(int? index) {
    if (state.status == GameStatus.won) return;
    if (state.status == GameStatus.lost) return;
    emit(state.copyWith(highlightedCell: () => index));
  }

  /// Locks the currently highlighted cell as a parameter value.
  ///
  /// Transitions to [GameStatus.readyToConfirm].
  /// If called when already in [GameStatus.readyToConfirm], re-picks
  /// the parameter so the player can change their choice before
  /// tapping Play.
  void lockParam() {
    if (state.highlightedCell == null) return;
    if (state.activeQuestionType == null) return;

    final number = GameState.numberForIndex(state.highlightedCell!);

    if (state.status == GameStatus.selectingParam ||
        state.status == GameStatus.readyToConfirm) {
      emit(
        state.copyWith(
          status: GameStatus.readyToConfirm,
          firstParam: () => number,
          highlightedCell: () => null,
        ),
      );
    }
  }

  /// Sets the first parameter directly to a raw value (e.g., a digit 0–9).
  ///
  /// Used by the digit picker for question types like
  /// [QuestionType.onesDigitIs] where the parameter isn't a
  /// grid cell number.
  void setDigitParam(int value) {
    if (state.activeQuestionType == null) return;
    emit(
      state.copyWith(
        status: GameStatus.readyToConfirm,
        firstParam: () => value,
      ),
    );
  }

  /// Applies the staged question with its locked parameters.
  ///
  /// On success, marks the question type as used (unless repeatable),
  /// increments the question count, and returns to the tray.
  void confirmQuestion() {
    if (!state.canConfirm) return;

    final type = state.activeQuestionType!;
    final result = QuestionEvaluator.apply(
      type: type,
      targetNumber: state.targetNumber,
      currentCells: state.cells,
      param1: state.firstParam,
      random: _shotgunRandom(),
    );

    final newQuestionCount = state.questionCount + 1;
    final usedTypes = {...state.usedQuestionTypes};
    if (!type.isRepeatable) {
      usedTypes.add(type);
    }

    // Win when only one possible cell remains.
    final remaining = result.cells.where((c) => c == CellState.possible).length;
    final isWin = remaining <= 1;

    if (isWin) {
      // Mark the target cell as revealed.
      final winCells = List<CellState>.from(result.cells);
      winCells[state.targetNumber - 1] = CellState.target;

      final score = ScoreCalculator.calculate(
        questions: newQuestionCount,
        seconds: state.elapsedSeconds,
      );
      emit(
        state.copyWith(
          cells: winCells,
          status: GameStatus.won,
          usedQuestionTypes: usedTypes,
          activeQuestionType: () => null,
          firstParam: () => null,
          highlightedCell: () => null,
          questionCount: newQuestionCount,
          score: () => score,
          lastResult: () => result.answer,
        ),
      );
      _clearSession();
    } else {
      // Check if the question cost pushed score to zero.
      final liveScore = ScoreCalculator.calculate(
        questions: newQuestionCount,
        seconds: state.elapsedSeconds,
      );
      final isLost = liveScore <= 0;

      emit(
        state.copyWith(
          cells: result.cells,
          status: isLost ? GameStatus.lost : GameStatus.playing,
          usedQuestionTypes: usedTypes,
          activeQuestionType: () => null,
          firstParam: () => null,
          highlightedCell: () => null,
          questionCount: newQuestionCount,
          timerStarted: true,
          score: isLost ? () => 0 : null,
          lastResult: () => result.answer,
        ),
      );

      if (isLost) {
        _clearSession();
      } else {
        _saveSession();
      }
    }
  }

  /// Persists the current game state to storage.
  void _saveSession() {
    final future = _storageRepository?.saveSession(_gameId, {
      'dailySeed': _dailySeed,
      'cells': state.cells.map((c) => c.index).toList(),
      'usedQuestionTypes': state.usedQuestionTypes.map((t) => t.index).toList(),
      'questionCount': state.questionCount,
      'elapsedSeconds': state.elapsedSeconds,
      'timerStarted': state.timerStarted,
    });
    if (future != null) unawaited(future);
  }

  /// Clears the saved session (game is over).
  void _clearSession() {
    final future = _storageRepository?.saveSession(_gameId, null);
    if (future != null) unawaited(future);
  }

  /// Increments the elapsed time by one second.
  ///
  /// Only counts after the first question has been played.
  /// Triggers a loss if the score reaches zero.
  void tick() {
    if (state.status == GameStatus.won) return;
    if (state.status == GameStatus.lost) return;
    if (!state.timerStarted) return;

    final newSeconds = state.elapsedSeconds + 1;
    final newScore = ScoreCalculator.calculate(
      questions: state.questionCount,
      seconds: newSeconds,
    );

    if (newScore <= 0) {
      emit(
        state.copyWith(
          elapsedSeconds: newSeconds,
          status: GameStatus.lost,
          score: () => 0,
        ),
      );
      _clearSession();
      return;
    }

    emit(state.copyWith(elapsedSeconds: newSeconds));
  }
}
