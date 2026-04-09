import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

part 'cascade_state.dart';

/// Manages the state of a single Cascade ball-routing puzzle session.
///
/// Handles ball assignment, lever flipping, drop simulation,
/// reset, win detection, and state persistence.
class CascadeCubit extends Cubit<CascadeState> {
  /// Creates a [CascadeCubit] that generates a puzzle from [dailySeed].
  CascadeCubit({
    required int dailySeed,
    required String dateKey,
    GameStorageRepository? storageRepository,
  }) : _storageRepository = storageRepository,
       _dateKey = dateKey,
       super(CascadeState.loading()) {
    _initialize(dailySeed, dateKey, storageRepository);
  }

  final GameStorageRepository? _storageRepository;
  final String _dateKey;

  static const _storagePrefix = 'cascade_state_';

  String get _storageKey => '$_storagePrefix$_dateKey';

  /// Snapshot of the board at the moment the user last tapped Drop.
  CascadeBoard? _preDropBoard;

  /// Snapshot of slot assignments at the moment the user last tapped Drop.
  List<BallId?>? _preDropSlots;

  Future<void> _initialize(
    int dailySeed,
    String dateKey,
    GameStorageRepository? storage,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;

    final result = await compute(PuzzleGenerator.generate, dailySeed);

    if (storage != null) {
      final session = storage.getSession('$_storagePrefix$dateKey');
      if (session != null) {
        try {
          final restoredState = _deserializeState(session, result);
          if (restoredState != null) {
            emit(restoredState);
            return;
          }
        }
        // Deserialization can fail due to schema changes or corrupted
        // data. Clear stale session and generate a fresh puzzle.
        // ignore: avoid_catching_errors
        on Object {
          unawaited(
            storage.saveSession('$_storagePrefix$dateKey', null),
          );
        }
      }
    }

    if (isClosed) return;
    emit(
      CascadeState(
        board: result.board,
        initialLevers: result.initialLevers,
      ),
    );
  }

  /// Resets with a new puzzle from [seed]. For playtesting only.
  void resetWithSeed(int seed) {
    emit(CascadeState.loading());
    _initialize(seed, _dateKey, null);
  }

  /// Assigns [ball] to the drop slot at [slotIndex].
  ///
  /// If the ball is already in another slot and the target slot has a
  /// ball, the two are swapped. Otherwise the ball is moved to the
  /// target slot and the old slot is cleared.
  void assignBall(BallId ball, int slotIndex) {
    if (state.status != CascadeStatus.configuring) return;
    if (slotIndex < 0 || slotIndex > 2) return;

    final slots = List<BallId?>.of(state.slotAssignments);

    // Find where the ball currently is (if anywhere).
    final sourceSlot = slots.indexOf(ball);

    if (sourceSlot == slotIndex) return; // Already there.

    // Swap: put whatever is in the target into the source slot.
    if (sourceSlot != -1) {
      slots[sourceSlot] = slots[slotIndex]; // may be null or another ball
    }
    slots[slotIndex] = ball;

    emit(state.copyWith(slotAssignments: slots));
    _persistSession();
  }

  /// Removes the ball from the slot at [slotIndex].
  void unassignBall(int slotIndex) {
    if (state.status != CascadeStatus.configuring) return;
    if (slotIndex < 0 || slotIndex > 2) return;
    if (state.slotAssignments[slotIndex] == null) return;

    final slots = List<BallId?>.of(state.slotAssignments);
    slots[slotIndex] = null;

    emit(state.copyWith(slotAssignments: slots));
    _persistSession();
  }

  /// Flips the lever at [leverIndex].
  void flipLever(int leverIndex) {
    if (state.status != CascadeStatus.configuring) return;
    if (leverIndex < 0 || leverIndex >= state.board.levers.length) {
      return;
    }

    emit(state.copyWith(board: state.board.flipLever(leverIndex)));
    _persistSession();
  }

  /// Starts the ball drop cascade.
  ///
  /// Transitions from `configuring` to `dropping`. Computes the full
  /// [DropResult] synchronously so the view can animate the paths.
  void drop() {
    if (state.status != CascadeStatus.configuring) return;
    if (!state.allBallsAssigned) return;

    // Snapshot the current configuration so Reset restores to it.
    _preDropBoard = state.board;
    _preDropSlots = List<BallId?>.of(state.slotAssignments);

    final assignments = state.slotAssignments.whereType<BallId>().toList();
    final result = BallSimulator.simulate(
      board: state.board,
      slotAssignments: assignments,
    );

    emit(
      state.copyWith(
        status: CascadeStatus.dropping,
        attempts: state.attempts + 1,
        dropResult: () => result,
      ),
    );
    _persistSession();
  }

  /// Called when the drop animation finishes (or is skipped).
  ///
  /// Transitions from `dropping` to `won` or `failed`.
  void completeDrop() {
    if (state.status != CascadeStatus.dropping) return;
    final result = state.dropResult;
    if (result == null) return;

    if (result.isWin) {
      final score = cascadeScore(state.attempts);
      emit(
        state.copyWith(
          status: CascadeStatus.won,
          score: () => score,
        ),
      );
      // Clear session on win.
      final future = _storageRepository?.saveSession(_storageKey, null);
      if (future != null) unawaited(future);
    } else {
      emit(state.copyWith(status: CascadeStatus.failed));
      _persistSession();
    }
  }

  /// Instantly resolves all remaining balls during drop animation.
  void skipAnimation() {
    if (state.status != CascadeStatus.dropping) return;
    completeDrop();
  }

  /// Resets the board to seed defaults for another attempt.
  ///
  /// Restores initial lever directions, clears ball assignments,
  /// preserves the attempt count.
  void reset() {
    if (state.status != CascadeStatus.failed) return;

    emit(
      state.copyWith(
        board: _preDropBoard ?? state.board.resetLevers(state.initialLevers),
        status: CascadeStatus.configuring,
        slotAssignments: _preDropSlots ?? defaultSlotAssignments,
        dropResult: () => null,
      ),
    );
    _persistSession();
  }

  void _persistSession() {
    final future = _storageRepository?.saveSession(_storageKey, {
      'levers': state.board.levers.map((l) => l.toJson()).toList(),
      'slotAssignments': state.slotAssignments
          .map((b) => b?.name)
          .toList(),
      'attempts': state.attempts,
      'status': state.status.name,
    });
    if (future != null) unawaited(future);
  }

  static CascadeState? _deserializeState(
    Map<String, dynamic> session,
    CascadeGenerateResult result,
  ) {
    final leverJsons =
        (session['levers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final levers = leverJsons.map(Lever.fromJson).toList();

    final slotJsons = (session['slotAssignments'] as List<dynamic>)
        .cast<String?>();
    final slots = slotJsons
        .map(
          (name) =>
              name != null ? BallId.values.byName(name) : null,
        )
        .toList();

    final attempts = session['attempts'] as int;
    final statusName = session['status'] as String?;

    // If the app was backgrounded during dropping, treat as failed.
    final status =
        statusName == CascadeStatus.dropping.name
            ? CascadeStatus.failed
            : statusName == CascadeStatus.won.name
                ? CascadeStatus.won
                : CascadeStatus.configuring;

    // If already won, restore with score.
    final score =
        status == CascadeStatus.won ? cascadeScore(attempts) : null;

    final board = CascadeBoard(
      levers: levers,
      binOrder: result.board.binOrder,
    );

    return CascadeState(
      board: board,
      initialLevers: result.initialLevers,
      status: status,
      slotAssignments: slots,
      attempts: attempts,
      score: score,
    );
  }
}
