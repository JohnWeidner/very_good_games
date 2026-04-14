import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/models/models.dart';

part 'signal_state.dart';

/// Manages the state of a single Signal grid puzzle session.
///
/// Handles cell toggling, drag painting/erasing, win detection,
/// and state persistence.
class SignalCubit extends Cubit<SignalState> with GameTimerMixin<SignalState> {
  /// Creates a [SignalCubit] that generates a puzzle from [dailySeed].
  ///
  /// Starts in [SignalStatus.loading] and generates the puzzle
  /// asynchronously so the UI can show a progress indicator.
  /// If a persisted session exists for [dateKey], restores it.
  SignalCubit({
    required int dailySeed,
    required String dateKey,
    GameStorageRepository? storageRepository,
  }) : _storageRepository = storageRepository,
       _dateKey = dateKey,
       super(SignalState.loading()) {
    _initialize(dailySeed, dateKey, storageRepository);
  }

  final GameStorageRepository? _storageRepository;
  final String _dateKey;

  static const _storagePrefix = 'signal_state_';

  String get _storageKey => '$_storagePrefix$_dateKey';

  Future<void> _initialize(
    int dailySeed,
    String dateKey,
    GameStorageRepository? storage,
  ) async {
    // Yield to let the UI paint the loading state.
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;

    final result = await compute(_generatePuzzle, dailySeed);

    // Try to restore persisted state.
    if (storage != null) {
      final session = storage.getSession('$_storagePrefix$dateKey');
      if (session != null) {
        try {
          final restoredState = _deserializeState(
            session,
            result.puzzle,
            result.solutionWallCount,
          );
          if (restoredState != null) {
            emit(restoredState);
            initTimer(
              initialSeconds: restoredState.elapsedSeconds,
              alreadyStarted: restoredState.timerStarted,
            );
            return;
          }
        } on Object {
          // Corrupted data — discard and start fresh.
          unawaited(storage.saveSession('$_storagePrefix$dateKey', null));
        }
      }
    }

    if (isClosed) return;
    final signals = SignalCalculator.calculate(result.puzzle);
    emit(
      SignalState(
        grid: result.puzzle,
        towerSignals: signals,
        solutionWallCount: result.solutionWallCount,
      ),
    );
  }

  static ({Grid puzzle, int solutionWallCount}) _generatePuzzle(int seed) {
    return PuzzleGenerator.generate(seed);
  }

  /// Resets with a new puzzle from [seed]. For playtesting only.
  void resetWithSeed(int seed) {
    resetTimer();
    emit(SignalState.loading());
    _initializeFromSeed(seed);
  }

  Future<void> _initializeFromSeed(int seed) async {
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;

    final result = await compute(_generatePuzzle, seed);
    if (isClosed) return;

    final signals = SignalCalculator.calculate(result.puzzle);
    emit(
      SignalState(
        grid: result.puzzle,
        towerSignals: signals,
        solutionWallCount: result.solutionWallCount,
      ),
    );
  }

  /// Toggles a cell between empty and wall (tap interaction).
  ///
  /// No-op on tower cells or when game is won.
  void toggleCell(int row, int col) {
    if (state.status != SignalStatus.playing) return;
    final cell = state.grid.cellAt(row, col);
    if (cell is Tower) return;

    final isPlacingWall = cell is! WallCell;
    if (isPlacingWall && state.atWallLimit) return;

    startTimer();
    final newCell = isPlacingWall ? Cell.wall : Cell.empty;
    final newGrid = state.grid.setCell(row, col, newCell);
    final signals = SignalCalculator.calculate(newGrid);
    final newMoveCount = state.moveCount + 1;

    emit(
      state.copyWith(
        grid: newGrid,
        towerSignals: signals,
        moveCount: newMoveCount,
        timerStarted: true,
      ),
    );

    _checkWinAndPersist();
  }

  /// Checks if all towers are satisfied. If won, emits win state and
  /// clears persisted session. Otherwise persists current state.
  void _checkWinAndPersist() {
    final signals = state.towerSignals;
    var isWin = true;
    for (final pos in state.grid.towerPositions) {
      final tower = state.grid.cellAt(pos.$1, pos.$2) as Tower;
      if (signals[pos] != tower.targetCount) {
        isWin = false;
        break;
      }
    }

    if (isWin) {
      disposeTimer();
      emit(
        state.copyWith(
          status: SignalStatus.won,
          score: () => SignalScoreCalculator.calculate(state.moveCount),
        ),
      );
      final future = _storageRepository?.saveSession(_storageKey, null);
      if (future != null) unawaited(future);
    } else {
      final future = _storageRepository?.saveSession(_storageKey, {
        'cells': state.grid.cells.map(_serializeCell).toList(),
        'moveCount': state.moveCount,
        'elapsedSeconds': state.elapsedSeconds,
        'timerStarted': state.timerStarted,
      });
      if (future != null) unawaited(future);
    }
  }

  static int _serializeCell(Cell cell) => switch (cell) {
    EmptyCell() => 0,
    WallCell() => 1,
    Tower(targetCount: final t) => 100 + t,
  };

  static SignalState? _deserializeState(
    Map<String, dynamic> session,
    Grid puzzleGrid,
    int solutionWallCount,
  ) {
    final cellInts = (session['cells'] as List<dynamic>).cast<int>();
    if (cellInts.length != puzzleGrid.cells.length) return null;

    final cells = <Cell>[];
    for (var i = 0; i < cellInts.length; i++) {
      final v = cellInts[i];
      if (v == 0) {
        cells.add(Cell.empty);
      } else if (v == 1) {
        cells.add(Cell.wall);
      } else if (v >= 100) {
        // Tower — use target from the generated puzzle, not stored value.
        final puzzleCell = puzzleGrid.cells[i];
        if (puzzleCell is Tower) {
          cells.add(puzzleCell);
        } else {
          return null; // Corrupted — tower mismatch.
        }
      } else {
        return null; // Unknown cell type.
      }
    }

    final grid = Grid(size: puzzleGrid.size, cells: cells);
    final signals = SignalCalculator.calculate(grid);
    final moveCount = session['moveCount'] as int;

    final savedElapsedSeconds = session['elapsedSeconds'] as int? ?? 0;
    final savedTimerStarted = session['timerStarted'] as bool? ?? false;

    return SignalState(
      grid: grid,
      towerSignals: signals,
      moveCount: moveCount,
      solutionWallCount: solutionWallCount,
      elapsedSeconds: savedElapsedSeconds,
      timerStarted: savedTimerStarted,
    );
  }

  @override
  void onTimerTick(int elapsedSeconds) {
    if (state.status != SignalStatus.playing) return;
    emit(state.copyWith(elapsedSeconds: elapsedSeconds));
  }

  @override
  Future<void> close() {
    disposeTimer();
    return super.close();
  }
}
