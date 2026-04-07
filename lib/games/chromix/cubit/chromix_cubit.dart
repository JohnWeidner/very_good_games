import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

part 'chromix_state.dart';

/// Manages the state of a single Chromix color-mixing puzzle session.
///
/// Handles color selection, placement, mixing, undo, win detection,
/// and state persistence.
class ChromixCubit extends Cubit<ChromixState> {
  /// Creates a [ChromixCubit] that generates a puzzle from [dailySeed].
  ChromixCubit({
    required int dailySeed,
    required String dateKey,
    GameStorageRepository? storageRepository,
  }) : _storageRepository = storageRepository,
       _dateKey = dateKey,
       super(ChromixState.loading()) {
    _initialize(dailySeed, dateKey, storageRepository);
  }

  final GameStorageRepository? _storageRepository;
  final String _dateKey;

  static const _storagePrefix = 'chromix_state_';

  String get _storageKey => '$_storagePrefix$_dateKey';

  Future<void> _initialize(
    int dailySeed,
    String dateKey,
    GameStorageRepository? storage,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;

    final result = await compute(_generatePuzzle, dailySeed);

    if (storage != null) {
      final session = storage.getSession('$_storagePrefix$dateKey');
      if (session != null) {
        try {
          final restoredState = _deserializeState(session, result);
          if (restoredState != null) {
            emit(restoredState);
            return;
          }
        } on Object {
          unawaited(storage.saveSession('$_storagePrefix$dateKey', null));
        }
      }
    }

    if (isClosed) return;
    emit(
      ChromixState(
        grid: result.puzzle,
        target: result.target,
        optimalMoves: result.optimalMoves,
      ),
    );
  }

  static GenerateResult _generatePuzzle(int seed) {
    return PuzzleGenerator.generate(seed);
  }

  /// Resets with a new puzzle from [seed]. For playtesting only.
  void resetWithSeed(int seed) {
    emit(ChromixState.loading());
    _initializeFromSeed(seed);
  }

  Future<void> _initializeFromSeed(int seed) async {
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;

    final result = await compute(_generatePuzzle, seed);
    if (isClosed) return;

    emit(
      ChromixState(
        grid: result.puzzle,
        target: result.target,
        optimalMoves: result.optimalMoves,
      ),
    );
  }

  /// Updates the currently selected primary color.
  ///
  /// No-op if [color] is not a primary.
  void selectColor(ChromixColor color) {
    if (!color.isPrimary) return;
    if (state.status != ChromixStatus.playing) return;
    emit(state.copyWith(selectedColor: color));
  }

  /// Places the selected color on the cell at ([row], [col]).
  ///
  /// - Empty cell: places the selected primary.
  /// - Primary cell with different color: mixes to create secondary.
  /// - Same color or locked cell: no-op.
  void placeColor(int row, int col) {
    if (state.status != ChromixStatus.playing) return;

    final cellIndex = row * ChromixGrid.size + col;
    final cell = state.grid.cellAt(row, col);

    switch (cell) {
      case EmptyCell():
        _placeOnEmpty(row, col, cellIndex, cell);
      case ColorCell():
        _placeOnColor(row, col, cellIndex, cell);
      case BlockerCell():
        return; // No-op on blockers.
    }
  }

  void _placeOnEmpty(int row, int col, int cellIndex, EmptyCell cell) {
    final newCell = ColorCell(state.selectedColor);
    final newGrid = state.grid.setCell(row, col, newCell);
    final record = MoveRecord(cellIndex: cellIndex, previousCell: cell);

    emit(
      state.copyWith(
        grid: newGrid,
        moveCount: state.moveCount + 1,
        moveHistory: [...state.moveHistory, record],
      ),
    );

    _checkWinAndPersist();
  }

  void _placeOnColor(int row, int col, int cellIndex, ColorCell cell) {
    if (cell.isLocked) return; // Secondary colors can't be changed.
    if (cell.color == state.selectedColor) return; // Same color — no-op.

    final mixed = ColorMixer.mix(cell.color, state.selectedColor);
    if (mixed == null) return;

    final newCell = ColorCell(mixed);
    final newGrid = state.grid.setCell(row, col, newCell);
    final record = MoveRecord(cellIndex: cellIndex, previousCell: cell);

    emit(
      state.copyWith(
        grid: newGrid,
        moveCount: state.moveCount + 1,
        moveHistory: [...state.moveHistory, record],
      ),
    );

    _checkWinAndPersist();
  }

  /// Undoes the last move, restoring the previous cell state.
  ///
  /// Increments [ChromixState.undoCount]; does not decrement moveCount.
  /// No-op if history is empty.
  void undo() {
    if (state.status != ChromixStatus.playing) return;
    if (state.moveHistory.isEmpty) return;

    final history = List<MoveRecord>.of(state.moveHistory);
    final record = history.removeLast();

    final row = record.cellIndex ~/ ChromixGrid.size;
    final col = record.cellIndex % ChromixGrid.size;
    final newGrid = state.grid.setCell(row, col, record.previousCell);

    emit(
      state.copyWith(
        grid: newGrid,
        undoCount: state.undoCount + 1,
        moveHistory: history,
      ),
    );

    _persistSession();
  }

  void _checkWinAndPersist() {
    final distributionMatches =
        mapEquals(state.currentDistribution, state.target);
    if (state.grid.isFullyFilled && distributionMatches) {
      final score = chromixScore(state.moveCount, state.undoCount);
      emit(
        state.copyWith(
          status: ChromixStatus.won,
          score: () => score,
        ),
      );
      final future = _storageRepository?.saveSession(_storageKey, null);
      if (future != null) unawaited(future);
    } else {
      _persistSession();
    }
  }

  void _persistSession() {
    final future = _storageRepository?.saveSession(_storageKey, {
      'cells': state.grid.cells.map((c) => c.toJson()).toList(),
      'moveCount': state.moveCount,
      'undoCount': state.undoCount,
      'moveHistory': state.moveHistory.map((m) => m.toJson()).toList(),
      'selectedColor': state.selectedColor.name,
    });
    if (future != null) unawaited(future);
  }

  static ChromixState? _deserializeState(
    Map<String, dynamic> session,
    GenerateResult result,
  ) {
    final cellJsons = (session['cells'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (cellJsons.length != ChromixGrid.size * ChromixGrid.size) {
      return null;
    }

    final cells = cellJsons.map(ChromixCell.fromJson).toList();
    final grid = ChromixGrid(cells: cells);

    final moveCount = session['moveCount'] as int;
    final undoCount = session['undoCount'] as int? ?? 0;

    final historyJsons = (session['moveHistory'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    final moveHistory =
        historyJsons?.map(MoveRecord.fromJson).toList() ?? const [];

    final selectedColorName = session['selectedColor'] as String?;
    final selectedColor = selectedColorName != null
        ? ChromixColor.values.byName(selectedColorName)
        : ChromixColor.red;

    return ChromixState(
      grid: grid,
      target: result.target,
      optimalMoves: result.optimalMoves,
      moveCount: moveCount,
      undoCount: undoCount,
      moveHistory: moveHistory,
      selectedColor: selectedColor,
    );
  }
}
