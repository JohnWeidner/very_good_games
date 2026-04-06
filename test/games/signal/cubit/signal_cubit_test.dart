import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/models/models.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

/// Finds a set of wall cell indices that solves the puzzle for [seed].
///
/// Uses backtracking to find a valid solution within the minimum wall count.
Set<int> _findSolutionWalls(int seed) {
  final result = PuzzleGenerator.generate(seed);
  final puzzle = result.puzzle;
  final wallLimit = result.solutionWallCount;
  final size = puzzle.size;

  final emptyCells = <int>[];
  for (var i = 0; i < puzzle.cells.length; i++) {
    if (puzzle.cells[i] is EmptyCell) emptyCells.add(i);
  }

  final towers = <({int row, int col, int target})>[];
  for (final pos in puzzle.towerPositions) {
    final tower = puzzle.cellAt(pos.$1, pos.$2) as Tower;
    towers.add((row: pos.$1, col: pos.$2, target: tower.targetCount));
  }

  final solution = <int>{};

  bool solve(Grid grid, int index, int placed) {
    final signals = SignalCalculator.calculate(grid);

    // Prune: any tower below target can't be fixed by adding walls.
    for (final t in towers) {
      final current = signals[(t.row, t.col)] ?? 0;
      if (current < t.target) return false;
    }

    if (placed == wallLimit) {
      for (final t in towers) {
        if (signals[(t.row, t.col)] != t.target) return false;
      }
      return true;
    }

    if (emptyCells.length - index < wallLimit - placed) return false;

    for (var i = index; i < emptyCells.length; i++) {
      final ci = emptyCells[i];
      solution.add(ci);
      final withWall = grid.setCell(ci ~/ size, ci % size, Cell.wall);
      if (solve(withWall, i + 1, placed + 1)) return true;
      solution.remove(ci);
    }
    return false;
  }

  solve(puzzle, 0, 0);
  return solution;
}

/// Waits for the cubit to finish loading (async puzzle generation).
Future<void> _waitForReady(SignalCubit cubit) async {
  if (cubit.state.status != SignalStatus.loading) return;
  await cubit.stream.firstWhere((s) => s.status != SignalStatus.loading);
}

/// Finds the first empty cell in a grid, returning (row, col).
(int, int) _firstEmptyCell(Grid grid) {
  for (var r = 0; r < grid.size; r++) {
    for (var c = 0; c < grid.size; c++) {
      if (grid.cellAt(r, c) is EmptyCell) return (r, c);
    }
  }
  throw StateError('No empty cell found');
}

void main() {
  const seed = 42;
  const dateKey = '2026-04-03';

  group('SignalCubit', () {
    test('initial state has playing status and zero moves', () async {
      final cubit = SignalCubit(dailySeed: seed, dateKey: dateKey);
      await _waitForReady(cubit);

      expect(cubit.state.status, equals(SignalStatus.playing));
      expect(cubit.state.moveCount, equals(0));
      expect(cubit.state.score, isNull);
      expect(cubit.state.grid.towerPositions, isNotEmpty);

      cubit.close();
    });

    test('initial grid matches PuzzleGenerator output', () async {
      final cubit = SignalCubit(dailySeed: seed, dateKey: dateKey);
      await _waitForReady(cubit);
      final expected = PuzzleGenerator.generate(seed);

      expect(cubit.state.grid, equals(expected.puzzle));
      expect(cubit.state.solutionWallCount, equals(expected.solutionWallCount));

      cubit.close();
    });

    group('toggleCell', () {
      blocTest<SignalCubit, SignalState>(
        'toggles empty cell to wall and increments moveCount',
        build: () => SignalCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit.toggleCell(r, c);
        },
        verify: (cubit) {
          final (r, c) = _firstEmptyCell(PuzzleGenerator.generate(seed).puzzle);
          expect(cubit.state.grid.cellAt(r, c), isA<WallCell>());
          expect(cubit.state.moveCount, equals(1));
        },
      );

      blocTest<SignalCubit, SignalState>(
        'toggles wall back to empty',
        build: () => SignalCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit
            ..toggleCell(r, c)
            ..toggleCell(r, c);
        },
        verify: (cubit) {
          final (r, c) = _firstEmptyCell(PuzzleGenerator.generate(seed).puzzle);
          expect(cubit.state.grid.cellAt(r, c), isA<EmptyCell>());
          expect(cubit.state.moveCount, equals(2));
        },
      );

      test('is no-op on tower cells', () async {
        final cubit = SignalCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        final stateBefore = cubit.state;
        final pos = cubit.state.grid.towerPositions.first;
        cubit.toggleCell(pos.$1, pos.$2);

        expect(cubit.state, equals(stateBefore));
        cubit.close();
      });

      blocTest<SignalCubit, SignalState>(
        'recalculates tower signals after toggle',
        build: () => SignalCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit.toggleCell(r, c);
        },
        verify: (cubit) {
          final expected = SignalCalculator.calculate(cubit.state.grid);
          expect(cubit.state.towerSignals, equals(expected));
        },
      );
    });

    group('win detection', () {
      blocTest<SignalCubit, SignalState>(
        'detects win when all towers are satisfied',
        build: () => SignalCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final wallIndices = _findSolutionWalls(seed);
          final size = cubit.state.grid.size;
          for (final idx in wallIndices) {
            cubit.toggleCell(idx ~/ size, idx % size);
          }
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(SignalStatus.won));
          expect(cubit.state.score, isNotNull);
          expect(cubit.state.score, greaterThanOrEqualTo(0));
        },
      );

      blocTest<SignalCubit, SignalState>(
        'toggleCell is no-op after winning',
        build: () => SignalCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // Win first.
          final wallIndices = _findSolutionWalls(seed);
          final size = cubit.state.grid.size;
          for (final idx in wallIndices) {
            cubit.toggleCell(idx ~/ size, idx % size);
          }
          // Try toggling after win.
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit.toggleCell(r, c);
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(SignalStatus.won));
          // moveCount should equal the wall count, not wall count + 1.
          expect(
            cubit.state.moveCount,
            equals(_findSolutionWalls(seed).length),
          );
        },
      );
    });

    group('persistence', () {
      late GameStorageRepository storage;

      setUp(() {
        storage = _MockGameStorageRepository();
      });

      test('saves state after toggleCell', () async {
        when(() => storage.getSession(any())).thenReturn(null);
        when(() => storage.saveSession(any(), any())).thenAnswer((_) async {});

        final cubit = SignalCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit);

        final (r, c) = _firstEmptyCell(cubit.state.grid);
        cubit.toggleCell(r, c);

        verify(
          () => storage.saveSession(
            'signal_state_$dateKey',
            any(that: isA<Map<String, dynamic>>()),
          ),
        ).called(1);

        cubit.close();
      });

      test('clears session on win', () async {
        when(() => storage.getSession(any())).thenReturn(null);
        when(() => storage.saveSession(any(), any())).thenAnswer((_) async {});

        final cubit = SignalCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit);

        final wallIndices = _findSolutionWalls(seed);
        final size = cubit.state.grid.size;
        for (final idx in wallIndices) {
          cubit.toggleCell(idx ~/ size, idx % size);
        }

        // The last call should clear the session (null).
        verify(
          () => storage.saveSession('signal_state_$dateKey', null),
        ).called(1);

        cubit.close();
      });

      test('restores state from storage', () async {
        // First, use a real storage to create a saved session.
        final realStorage = _RealStorageHelper();
        final cubit1 = SignalCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: realStorage,
        );
        await _waitForReady(cubit1);
        final (r, c) = _firstEmptyCell(cubit1.state.grid);
        cubit1.toggleCell(r, c);
        final savedGrid = cubit1.state.grid;
        cubit1.close();

        // Now mock storage to return that session.
        when(
          () => storage.getSession('signal_state_$dateKey'),
        ).thenReturn(realStorage.lastSavedSession);
        when(() => storage.saveSession(any(), any())).thenAnswer((_) async {});

        final cubit2 = SignalCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit2);

        expect(cubit2.state.grid, equals(savedGrid));
        expect(cubit2.state.moveCount, equals(1));

        cubit2.close();
      });

      test('handles corrupted session gracefully', () async {
        when(
          () => storage.getSession('signal_state_$dateKey'),
        ).thenReturn({'cells': 'invalid'});
        when(() => storage.saveSession(any(), any())).thenAnswer((_) async {});

        final cubit = SignalCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit);

        // Should start fresh, not crash.
        expect(cubit.state.status, equals(SignalStatus.playing));
        expect(cubit.state.moveCount, equals(0));

        cubit.close();
      });
    });
  });
}

/// Helper that wraps a real SharedPreferences-backed storage to capture
/// the last saved session for use in mock setup.
class _RealStorageHelper implements GameStorageRepository {
  final _sessions = <String, Map<String, dynamic>?>{};

  Map<String, dynamic>? get lastSavedSession => _sessions.values.last;

  @override
  Map<String, dynamic>? getSession(String gameId) => _sessions[gameId];

  @override
  Future<void> saveSession(String gameId, Map<String, dynamic>? session) async {
    _sessions[gameId] = session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
