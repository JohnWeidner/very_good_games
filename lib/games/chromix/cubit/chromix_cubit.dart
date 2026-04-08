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
/// Handles drag interaction, color mixing, overpower, undo,
/// win detection, contiguity checking, and state persistence.
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
  static const _overpowerDuration = Duration(milliseconds: 500);

  String get _storageKey => '$_storagePrefix$_dateKey';

  Timer? _overpowerTimer;
  int? _overpowerCellIndex;
  ChromixColor? _overpowerColor;

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
    _cancelOverpowerTimer();
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

  /// Begins a drag from the cell at ([row], [col]).
  ///
  /// Only primary-colored cells can initiate a drag.
  void startDrag(int row, int col) {
    if (state.status != ChromixStatus.playing) return;

    final cell = state.grid.cellAt(row, col);
    if (cell is! ColorCell) return;
    if (!cell.color.isPrimary) return;

    emit(
      state.copyWith(
        dragOrigin: () => (row: row, col: col),
        dragColor: () => cell.color,
      ),
    );
  }

  /// Handles the drag moving to cell ([row], [col]).
  ///
  /// Must be orthogonally adjacent to the drag origin.
  void dragTo(int row, int col) {
    if (state.status != ChromixStatus.playing) return;
    final origin = state.dragOrigin;
    final dragColor = state.dragColor;
    if (origin == null || dragColor == null) return;

    // Must be orthogonally adjacent.
    final dr = (row - origin.row).abs();
    final dc = (col - origin.col).abs();
    if (dr + dc != 1) return;

    final cellIndex = row * ChromixGrid.size + col;
    final targetCell = state.grid.cellAt(row, col);

    switch (targetCell) {
      case BlockerCell():
        return;
      case EmptyCell():
        _placeOnEmpty(row, col, cellIndex, targetCell, dragColor);
      case ColorCell():
        _handleDragOntoColor(row, col, cellIndex, targetCell, dragColor);
    }
  }

  void _placeOnEmpty(
    int row,
    int col,
    int cellIndex,
    EmptyCell cell,
    ChromixColor dragColor,
  ) {
    final newCell = ColorCell(dragColor);
    final newGrid = state.grid.setCell(row, col, newCell);
    final record = MoveRecord(cellIndex: cellIndex, previousCell: cell);

    emit(
      state.copyWith(
        grid: newGrid,
        moveCount: state.moveCount + 1,
        moveHistory: [...state.moveHistory, record],
      ),
    );

    _recomputeContiguityAndCheckWin();
  }

  void _handleDragOntoColor(
    int row,
    int col,
    int cellIndex,
    ColorCell targetCell,
    ChromixColor dragColor,
  ) {
    if (targetCell.isLocked) return; // Secondary cells are locked.
    if (targetCell.color == dragColor) return; // Same color — no-op.

    if (dragColor.isPrimary && targetCell.color.isPrimary) {
      // MIX: place the secondary.
      final mixed = ColorMixer.mix(targetCell.color, dragColor);
      if (mixed == null) return;

      final newCell = ColorCell(mixed);
      final newGrid = state.grid.setCell(row, col, newCell);
      final record = MoveRecord(
        cellIndex: cellIndex,
        previousCell: targetCell,
      );

      emit(
        state.copyWith(
          grid: newGrid,
          moveCount: state.moveCount + 1,
          moveHistory: [...state.moveHistory, record],
        ),
      );

      _recomputeContiguityAndCheckWin();
      // Only start overpower timer if the mix didn't already win.
      if (state.status != ChromixStatus.won) {
        _startOverpowerTimer(cellIndex, dragColor, mixed);
      }
    } else if (dragColor.isPrimary && targetCell.color.isSecondary) {
      // OVERPOWER immediately: replace secondary with dragged primary.
      final newCell = ColorCell(dragColor);
      final newGrid = state.grid.setCell(row, col, newCell);
      final record = MoveRecord(
        cellIndex: cellIndex,
        previousCell: targetCell,
      );

      emit(
        state.copyWith(
          grid: newGrid,
          moveCount: state.moveCount + 1,
          moveHistory: [...state.moveHistory, record],
        ),
      );

      _recomputeContiguityAndCheckWin();
    }
  }

  void _startOverpowerTimer(
    int cellIndex,
    ChromixColor dragColor,
    ChromixColor mixedColor,
  ) {
    _cancelOverpowerTimer();
    _overpowerCellIndex = cellIndex;
    _overpowerColor = dragColor;
    _overpowerTimer = Timer(_overpowerDuration, _onOverpowerTimeout);
  }

  void _onOverpowerTimeout() {
    if (isClosed) return;
    if (state.status != ChromixStatus.playing) return;

    final cellIndex = _overpowerCellIndex;
    final overpowerColor = _overpowerColor;
    if (cellIndex == null || overpowerColor == null) return;

    final row = cellIndex ~/ ChromixGrid.size;
    final col = cellIndex % ChromixGrid.size;
    final currentCell = state.grid.cellAt(row, col);

    // The cell should currently hold the mixed color.
    if (currentCell is! ColorCell) return;

    final newCell = ColorCell(overpowerColor);
    final newGrid = state.grid.setCell(row, col, newCell);
    // This is a SECOND move on the same cell (overpower after mix).
    final record = MoveRecord(
      cellIndex: cellIndex,
      previousCell: currentCell,
    );

    emit(
      state.copyWith(
        grid: newGrid,
        moveCount: state.moveCount + 1,
        moveHistory: [...state.moveHistory, record],
      ),
    );

    _overpowerCellIndex = null;
    _overpowerColor = null;

    _recomputeContiguityAndCheckWin();
  }

  void _cancelOverpowerTimer() {
    _overpowerTimer?.cancel();
    _overpowerTimer = null;
    _overpowerCellIndex = null;
    _overpowerColor = null;
  }

  /// Ends the current drag gesture.
  void endDrag() {
    _cancelOverpowerTimer();
    if (state.dragOrigin != null || state.dragColor != null) {
      emit(
        state.copyWith(
          dragOrigin: () => null,
          dragColor: () => null,
        ),
      );
    }
  }

  /// Undoes the last move, restoring the previous cell state.
  ///
  /// Increments [ChromixState.undoCount]; does not decrement moveCount.
  /// No-op if history is empty.
  void undo() {
    if (state.status != ChromixStatus.playing) return;
    if (state.moveHistory.isEmpty) return;

    _cancelOverpowerTimer();

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

    _recomputeContiguity();
    _persistSession();
  }

  /// Recomputes contiguity violation and checks win condition.
  void _recomputeContiguityAndCheckWin() {
    _recomputeContiguity();
    _checkWinAndPersist();
  }

  /// Recomputes `hasContiguityViolation` from the current grid.
  ///
  /// Only checks colors whose placed count matches their target count,
  /// to avoid noisy feedback on partially-filled grids.
  void _recomputeContiguity() {
    final distribution = state.currentDistribution;
    var hasViolation = false;

    for (final entry in state.target.entries) {
      final color = entry.key;
      final targetCount = entry.value;
      final currentCount = distribution[color] ?? 0;

      if (currentCount == targetCount && currentCount > 1) {
        // Check if this color's cells form a single connected group.
        if (!_isColorContiguous(color)) {
          hasViolation = true;
          break;
        }
      }
    }

    if (hasViolation != state.hasContiguityViolation) {
      emit(state.copyWith(hasContiguityViolation: hasViolation));
    }
  }

  bool _isColorContiguous(ChromixColor color) {
    const size = ChromixGrid.size;
    final indices = <int>[];
    for (var i = 0; i < state.grid.cells.length; i++) {
      final cell = state.grid.cells[i];
      if (cell is ColorCell && cell.color == color) {
        indices.add(i);
      }
    }
    if (indices.length <= 1) return true;

    final indexSet = indices.toSet();
    final visited = <int>{indices.first};
    final queue = [indices.first];
    var head = 0;

    while (head < queue.length) {
      final current = queue[head++];
      final row = current ~/ size;
      final col = current % size;

      for (final n in [
        if (row > 0) (row - 1) * size + col,
        if (row < size - 1) (row + 1) * size + col,
        if (col > 0) row * size + (col - 1),
        if (col < size - 1) row * size + (col + 1),
      ]) {
        if (indexSet.contains(n) && visited.add(n)) {
          queue.add(n);
        }
      }
    }

    return visited.length == indices.length;
  }

  void _checkWinAndPersist() {
    final distributionMatches =
        mapEquals(state.currentDistribution, state.target);
    final contiguous = allGroupsContiguous(state.grid);
    if (state.grid.isFullyFilled && distributionMatches && contiguous) {
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
    // Drag state (dragOrigin, dragColor) is intentionally not persisted —
    // it is transient and resets on app restart.
    final future = _storageRepository?.saveSession(_storageKey, {
      'cells': state.grid.cells.map((c) => c.toJson()).toList(),
      'moveCount': state.moveCount,
      'undoCount': state.undoCount,
      'moveHistory': state.moveHistory.map((m) => m.toJson()).toList(),
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

    // Verify the restored grid is compatible with the generated puzzle.
    // Blocker positions must match and target sum must equal non-blockers.
    final targetSum = result.target.values.fold<int>(0, (a, b) => a + b);
    if (grid.nonBlockerCount != targetSum) return null;
    for (var i = 0; i < cells.length; i++) {
      final restored = cells[i];
      final generated = result.puzzle.cells[i];
      if (restored is BlockerCell != generated is BlockerCell) return null;
    }

    final moveCount = session['moveCount'] as int;
    final undoCount = session['undoCount'] as int? ?? 0;

    final historyJsons = (session['moveHistory'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    final moveHistory =
        historyJsons?.map(MoveRecord.fromJson).toList() ?? const [];

    // Recompute hasContiguityViolation from the restored grid.
    final hasViolation = _computeContiguityViolation(
      grid,
      result.target,
    );

    return ChromixState(
      grid: grid,
      target: result.target,
      optimalMoves: result.optimalMoves,
      moveCount: moveCount,
      undoCount: undoCount,
      moveHistory: moveHistory,
      hasContiguityViolation: hasViolation,
    );
  }

  static bool _computeContiguityViolation(
    ChromixGrid grid,
    Map<ChromixColor, int> target,
  ) {
    final distribution = grid.colorDistribution;
    for (final entry in target.entries) {
      final color = entry.key;
      final targetCount = entry.value;
      final currentCount = distribution[color] ?? 0;

      if (currentCount == targetCount && currentCount > 1) {
        // Check contiguity for this color.
        const size = ChromixGrid.size;
        final indices = <int>[];
        for (var i = 0; i < grid.cells.length; i++) {
          final cell = grid.cells[i];
          if (cell is ColorCell && cell.color == color) {
            indices.add(i);
          }
        }
        if (indices.length <= 1) continue;

        final indexSet = indices.toSet();
        final visited = <int>{indices.first};
        final queue = [indices.first];
        var head = 0;
        while (head < queue.length) {
          final current = queue[head++];
          final row = current ~/ size;
          final col = current % size;
          for (final n in [
            if (row > 0) (row - 1) * size + col,
            if (row < size - 1) (row + 1) * size + col,
            if (col > 0) row * size + (col - 1),
            if (col < size - 1) row * size + (col + 1),
          ]) {
            if (indexSet.contains(n) && visited.add(n)) {
              queue.add(n);
            }
          }
        }
        if (visited.length != indices.length) return true;
      }
    }
    return false;
  }

  @override
  Future<void> close() {
    _cancelOverpowerTimer();
    return super.close();
  }
}
