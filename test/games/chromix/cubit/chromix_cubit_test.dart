import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

/// Waits for the cubit to finish loading (async puzzle generation).
Future<void> _waitForReady(ChromixCubit cubit) async {
  if (cubit.state.status != ChromixStatus.loading) return;
  await cubit.stream.firstWhere(
    (s) => s.status != ChromixStatus.loading,
  );
}

/// Finds the first empty cell in the grid, returning (row, col).
(int, int) _firstEmptyCell(ChromixGrid grid) {
  for (var r = 0; r < ChromixGrid.size; r++) {
    for (var c = 0; c < ChromixGrid.size; c++) {
      if (grid.cellAt(r, c) is EmptyCell) return (r, c);
    }
  }
  throw StateError('No empty cell found');
}

/// Finds the first primary ColorCell in the grid with a color
/// different from [selectedColor], returning (row, col).
(int, int) _firstDifferentPrimaryCell(
  ChromixGrid grid,
  ChromixColor selectedColor,
) {
  for (var r = 0; r < ChromixGrid.size; r++) {
    for (var c = 0; c < ChromixGrid.size; c++) {
      final cell = grid.cellAt(r, c);
      if (cell is ColorCell &&
          cell.color.isPrimary &&
          cell.color != selectedColor) {
        return (r, c);
      }
    }
  }
  throw StateError('No different primary cell found');
}

void main() {
  const seed = 42;
  const dateKey = '2026-04-07';

  group('ChromixCubit', () {
    test('initial state has playing status and zero moves', () async {
      final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
      await _waitForReady(cubit);

      expect(cubit.state.status, equals(ChromixStatus.playing));
      expect(cubit.state.moveCount, equals(0));
      expect(cubit.state.undoCount, equals(0));
      expect(cubit.state.score, isNull);
      expect(cubit.state.target, isNotEmpty);

      cubit.close();
    });

    test('initial grid matches PuzzleGenerator output', () async {
      final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
      await _waitForReady(cubit);
      final expected = PuzzleGenerator.generate(seed);

      expect(cubit.state.grid, equals(expected.puzzle));
      expect(cubit.state.target, equals(expected.target));
      expect(cubit.state.optimalMoves, equals(expected.optimalMoves));

      cubit.close();
    });

    group('selectColor', () {
      blocTest<ChromixCubit, ChromixState>(
        'changes selected color to a primary',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          cubit.selectColor(ChromixColor.blue);
        },
        verify: (cubit) {
          expect(
            cubit.state.selectedColor,
            equals(ChromixColor.blue),
          );
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'no-op for secondary colors',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          cubit.selectColor(ChromixColor.orange);
        },
        verify: (cubit) {
          expect(
            cubit.state.selectedColor,
            equals(ChromixColor.red),
          );
        },
      );
    });

    group('placeColor', () {
      blocTest<ChromixCubit, ChromixState>(
        'places primary on empty cell and increments moveCount',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit.placeColor(r, c);
        },
        verify: (cubit) {
          final result = PuzzleGenerator.generate(seed);
          final (r, c) = _firstEmptyCell(result.puzzle);
          final cell = cubit.state.grid.cellAt(r, c);
          expect(cell, isA<ColorCell>());
          expect(
            (cell as ColorCell).color,
            equals(ChromixColor.red),
          );
          expect(cubit.state.moveCount, equals(1));
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'mixes two different primaries into a secondary',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // Find a primary cell different from selected (red).
          final (r, c) = _firstDifferentPrimaryCell(
            cubit.state.grid,
            cubit.state.selectedColor,
          );
          final original =
              cubit.state.grid.cellAt(r, c) as ColorCell;
          cubit.placeColor(r, c);
          // Verify the result is a secondary.
          final mixed = ColorMixer.mix(
            original.color,
            ChromixColor.red,
          );
          expect(mixed, isNotNull);
          final result = cubit.state.grid.cellAt(r, c);
          expect(result, isA<ColorCell>());
          expect((result as ColorCell).color, equals(mixed));
        },
        verify: (cubit) {
          expect(cubit.state.moveCount, equals(1));
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'same color on cell is no-op',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // Place red on empty cell, then place red again.
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit
            ..placeColor(r, c)
            ..placeColor(r, c);
        },
        verify: (cubit) {
          // Only one move should register.
          expect(cubit.state.moveCount, equals(1));
        },
      );

      test('no-op on blocker cell', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        // Find a blocker cell.
        (int, int)? blockerPos;
        for (var r = 0; r < ChromixGrid.size; r++) {
          for (var c = 0; c < ChromixGrid.size; c++) {
            if (cubit.state.grid.cellAt(r, c) is BlockerCell) {
              blockerPos = (r, c);
              break;
            }
          }
          if (blockerPos != null) break;
        }

        if (blockerPos != null) {
          final before = cubit.state;
          cubit.placeColor(blockerPos.$1, blockerPos.$2);
          expect(cubit.state.moveCount, equals(before.moveCount));
        }

        cubit.close();
      });

      test('no-op on locked (secondary) cell', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        // First create a secondary by mixing.
        final (r, c) = _firstDifferentPrimaryCell(
          cubit.state.grid,
          cubit.state.selectedColor,
        );
        cubit.placeColor(r, c);
        final moveCountAfterMix = cubit.state.moveCount;

        // Now try placing on the secondary — should be no-op.
        cubit.placeColor(r, c);
        expect(cubit.state.moveCount, equals(moveCountAfterMix));

        cubit.close();
      });
    });

    group('undo', () {
      blocTest<ChromixCubit, ChromixState>(
        'reverts last move and increments undoCount',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit
            ..placeColor(r, c)
            ..undo();
        },
        verify: (cubit) {
          final result = PuzzleGenerator.generate(seed);
          final (r, c) = _firstEmptyCell(result.puzzle);
          expect(cubit.state.grid.cellAt(r, c), isA<EmptyCell>());
          expect(cubit.state.moveCount, equals(1));
          expect(cubit.state.undoCount, equals(1));
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'no-op on empty history',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          cubit.undo();
        },
        verify: (cubit) {
          expect(cubit.state.undoCount, equals(0));
          expect(cubit.state.moveHistory, isEmpty);
        },
      );
    });

    group('win detection', () {
      test('detects win when grid is fully filled and matches target',
          () async {
        // Use a known seed and solve the puzzle by brute-forcing.
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        // Manually fill all empty cells to match the target.
        final result = PuzzleGenerator.generate(seed);
        final solution = _solvePuzzle(result);

        for (final action in solution) {
          cubit
            ..selectColor(action.color)
            ..placeColor(action.row, action.col);
        }

        expect(cubit.state.status, equals(ChromixStatus.won));
        expect(cubit.state.score, isNotNull);

        cubit.close();
      });
    });

    group('persistence', () {
      late GameStorageRepository storage;

      setUp(() {
        storage = _MockGameStorageRepository();
      });

      test('saves state after placeColor', () async {
        when(() => storage.getSession(any())).thenReturn(null);
        when(
          () => storage.saveSession(any(), any()),
        ).thenAnswer((_) async {});

        final cubit = ChromixCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit);

        final (r, c) = _firstEmptyCell(cubit.state.grid);
        cubit.placeColor(r, c);

        verify(
          () => storage.saveSession(
            'chromix_state_$dateKey',
            any(that: isA<Map<String, dynamic>>()),
          ),
        ).called(1);

        cubit.close();
      });

      test('restores state from storage', () async {
        // Create a real session first.
        final realStorage = _RealStorageHelper();
        final cubit1 = ChromixCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: realStorage,
        );
        await _waitForReady(cubit1);
        final (r, c) = _firstEmptyCell(cubit1.state.grid);
        cubit1.placeColor(r, c);
        final savedGrid = cubit1.state.grid;
        final savedMoveCount = cubit1.state.moveCount;
        cubit1.close();

        // Mock storage to return that session.
        when(
          () => storage.getSession('chromix_state_$dateKey'),
        ).thenReturn(realStorage.lastSavedSession);
        when(
          () => storage.saveSession(any(), any()),
        ).thenAnswer((_) async {});

        final cubit2 = ChromixCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit2);

        expect(cubit2.state.grid, equals(savedGrid));
        expect(cubit2.state.moveCount, equals(savedMoveCount));

        cubit2.close();
      });

      test('handles corrupted session gracefully', () async {
        when(
          () => storage.getSession('chromix_state_$dateKey'),
        ).thenReturn({'cells': 'invalid'});
        when(
          () => storage.saveSession(any(), any()),
        ).thenAnswer((_) async {});

        final cubit = ChromixCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: storage,
        );
        await _waitForReady(cubit);

        expect(
          cubit.state.status,
          equals(ChromixStatus.playing),
        );
        expect(cubit.state.moveCount, equals(0));

        cubit.close();
      });
    });
  });
}

/// Brute-force solver that returns actions to solve the puzzle.
///
/// Uses backtracking: for each decision cell, tries each option and
/// checks if the target distribution is achievable.
List<({int row, int col, ChromixColor color})> _solvePuzzle(
  GenerateResult result,
) {
  final puzzle = result.puzzle;
  final target = result.target;
  final cells = List<ChromixCell>.of(puzzle.cells);
  final actions = <({int row, int col, ChromixColor color})>[];

  const primaries = [
    ChromixColor.red,
    ChromixColor.yellow,
    ChromixColor.blue,
  ];

  // Find decision indices (empty or layerable pre-filled primary).
  final decisions = <int>[];
  for (var i = 0; i < cells.length; i++) {
    final cell = cells[i];
    if (cell is EmptyCell) {
      decisions.add(i);
    } else if (cell is ColorCell &&
        cell.isPreFilled &&
        cell.color.isPrimary) {
      decisions.add(i);
    }
  }

  bool solve(int idx) {
    if (idx == decisions.length) {
      final grid = ChromixGrid(cells: cells);
      final dist = grid.colorDistribution;
      for (final color in ChromixColor.values) {
        if ((dist[color] ?? 0) != (target[color] ?? 0)) {
          return false;
        }
      }
      return true;
    }

    final cellIdx = decisions[idx];
    final cell = cells[cellIdx];
    final row = cellIdx ~/ ChromixGrid.size;
    final col = cellIdx % ChromixGrid.size;

    if (cell is EmptyCell) {
      for (final primary in primaries) {
        cells[cellIdx] = ColorCell(primary);
        actions.add((row: row, col: col, color: primary));
        if (solve(idx + 1)) return true;
        actions.removeLast();
        cells[cellIdx] = cell;
      }
    } else if (cell is ColorCell) {
      // Option 1: leave as-is (no action needed).
      if (solve(idx + 1)) return true;

      // Option 2: layer with another primary.
      for (final other in primaries) {
        if (other == cell.color) continue;
        final mixed = ColorMixer.mix(cell.color, other);
        if (mixed == null) continue;
        cells[cellIdx] = ColorCell(mixed);
        actions.add((row: row, col: col, color: other));
        if (solve(idx + 1)) return true;
        actions.removeLast();
        cells[cellIdx] = cell;
      }
    }

    return false;
  }

  solve(0);
  return actions;
}

/// Helper that captures saved sessions for use in mock setup.
class _RealStorageHelper implements GameStorageRepository {
  final _sessions = <String, Map<String, dynamic>?>{};

  Map<String, dynamic>? get lastSavedSession =>
      _sessions.values.last;

  @override
  Map<String, dynamic>? getSession(String gameId) =>
      _sessions[gameId];

  @override
  Future<void> saveSession(
    String gameId,
    Map<String, dynamic>? session,
  ) async {
    _sessions[gameId] = session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
