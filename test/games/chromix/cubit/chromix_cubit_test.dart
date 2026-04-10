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

/// Finds a primary ColorCell adjacent to a given cell.
(int, int)? _adjacentPrimaryCell(
  ChromixGrid grid,
  int row,
  int col,
) {
  for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
    final nr = row + dr;
    final nc = col + dc;
    if (nr < 0 || nr >= ChromixGrid.size) continue;
    if (nc < 0 || nc >= ChromixGrid.size) continue;
    final cell = grid.cellAt(nr, nc);
    if (cell is ColorCell && cell.color.isPrimary) return (nr, nc);
  }
  return null;
}

/// Finds a primary cell that has an adjacent empty cell.
({int row, int col, int emptyRow, int emptyCol})? _primaryWithAdjacentEmpty(
  ChromixGrid grid,
) {
  for (var r = 0; r < ChromixGrid.size; r++) {
    for (var c = 0; c < ChromixGrid.size; c++) {
      final cell = grid.cellAt(r, c);
      if (cell is ColorCell && cell.color.isPrimary) {
        for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= ChromixGrid.size) continue;
          if (nc < 0 || nc >= ChromixGrid.size) continue;
          if (grid.cellAt(nr, nc) is EmptyCell) {
            return (row: r, col: c, emptyRow: nr, emptyCol: nc);
          }
        }
      }
    }
  }
  return null;
}

/// Finds two adjacent primary cells with different colors.
({int row1, int col1, int row2, int col2})? _adjacentDifferentPrimaries(
  ChromixGrid grid,
) {
  for (var r = 0; r < ChromixGrid.size; r++) {
    for (var c = 0; c < ChromixGrid.size; c++) {
      final cell = grid.cellAt(r, c);
      if (cell is! ColorCell || !cell.color.isPrimary) continue;
      for (final (dr, dc) in [(0, 1), (1, 0)]) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= ChromixGrid.size || nc >= ChromixGrid.size) continue;
        final neighbor = grid.cellAt(nr, nc);
        if (neighbor is ColorCell &&
            neighbor.color.isPrimary &&
            neighbor.color != cell.color) {
          return (row1: r, col1: c, row2: nr, col2: nc);
        }
      }
    }
  }
  return null;
}

void main() {
  const seed = 42;
  // Seed with adjacent different primaries (for mixing/overpower tests).
  const mixSeed = 1;
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
      expect(cubit.state.dragOrigin, isNull);
      expect(cubit.state.dragColor, isNull);

      await cubit.close();
    });

    test('initial grid matches PuzzleGenerator output', () async {
      final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
      await _waitForReady(cubit);
      final expected = PuzzleGenerator.generate(seed);

      expect(cubit.state.grid, equals(expected.puzzle));
      expect(cubit.state.target, equals(expected.target));
      expect(cubit.state.optimalMoves, equals(expected.optimalMoves));

      await cubit.close();
    });

    group('startDrag', () {
      blocTest<ChromixCubit, ChromixState>(
        'sets dragOrigin and dragColor for primary cell',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // Find a primary cell.
          for (var r = 0; r < ChromixGrid.size; r++) {
            for (var c = 0; c < ChromixGrid.size; c++) {
              final cell = cubit.state.grid.cellAt(r, c);
              if (cell is ColorCell && cell.color.isPrimary) {
                cubit.startDrag(r, c);
                return;
              }
            }
          }
        },
        verify: (cubit) {
          expect(cubit.state.dragOrigin, isNotNull);
          expect(cubit.state.dragColor, isNotNull);
          expect(cubit.state.dragColor!.isPrimary, isTrue);
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'no-op for secondary cell',
        build: () => ChromixCubit(dailySeed: mixSeed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // First create a secondary by mixing via drag.
          final pair = _adjacentDifferentPrimaries(cubit.state.grid);
          expect(pair, isNotNull,
              reason: 'No adjacent different primaries');
          cubit
            ..startDrag(pair!.row1, pair.col1)
            ..dragTo(pair.row2, pair.col2)
            ..endDrag();
          // Now try to drag from the secondary.
          cubit.startDrag(pair.row2, pair.col2);
        },
        verify: (cubit) {
          expect(cubit.state.dragOrigin, isNull);
          expect(cubit.state.dragColor, isNull);
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'no-op for empty cell',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final (r, c) = _firstEmptyCell(cubit.state.grid);
          cubit.startDrag(r, c);
        },
        verify: (cubit) {
          expect(cubit.state.dragOrigin, isNull);
          expect(cubit.state.dragColor, isNull);
        },
      );

      test('no-op for blocker cell', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        for (var r = 0; r < ChromixGrid.size; r++) {
          for (var c = 0; c < ChromixGrid.size; c++) {
            if (cubit.state.grid.cellAt(r, c) is BlockerCell) {
              cubit.startDrag(r, c);
              expect(cubit.state.dragOrigin, isNull);
              await cubit.close();
              return;
            }
          }
        }
        await cubit.close();
      });
    });

    group('dragTo', () {
      blocTest<ChromixCubit, ChromixState>(
        'places primary on adjacent empty cell',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final pair = _primaryWithAdjacentEmpty(cubit.state.grid);
          if (pair == null) return;
          cubit
            ..startDrag(pair.row, pair.col)
            ..dragTo(pair.emptyRow, pair.emptyCol);
        },
        verify: (cubit) {
          final pair = _primaryWithAdjacentEmpty(
            PuzzleGenerator.generate(seed).puzzle,
          );
          if (pair == null) return;
          final cell = cubit.state.grid.cellAt(
            pair.emptyRow,
            pair.emptyCol,
          );
          expect(cell, isA<ColorCell>());
          expect(cubit.state.moveCount, equals(1));
        },
      );

      blocTest<ChromixCubit, ChromixState>(
        'rejects non-adjacent cell',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          // Find a primary cell and try to drag to a non-adjacent cell.
          for (var r = 0; r < ChromixGrid.size; r++) {
            for (var c = 0; c < ChromixGrid.size; c++) {
              final cell = cubit.state.grid.cellAt(r, c);
              if (cell is ColorCell && cell.color.isPrimary) {
                cubit.startDrag(r, c);
                // Try a non-adjacent cell (diagonal or far away).
                final farRow = (r + 2) % ChromixGrid.size;
                cubit.dragTo(farRow, c);
                return;
              }
            }
          }
        },
        verify: (cubit) {
          expect(cubit.state.moveCount, equals(0));
        },
      );

      test('rejects drag to blocker cell', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        // Find a primary cell adjacent to a blocker.
        for (var r = 0; r < ChromixGrid.size; r++) {
          for (var c = 0; c < ChromixGrid.size; c++) {
            final cell = cubit.state.grid.cellAt(r, c);
            if (cell is! ColorCell || !cell.color.isPrimary) continue;
            for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
              final nr = r + dr;
              final nc = c + dc;
              if (nr < 0 || nr >= ChromixGrid.size) continue;
              if (nc < 0 || nc >= ChromixGrid.size) continue;
              if (cubit.state.grid.cellAt(nr, nc) is BlockerCell) {
                cubit
                  ..startDrag(r, c)
                  ..dragTo(nr, nc);
                expect(cubit.state.moveCount, equals(0));
                await cubit.close();
                return;
              }
            }
          }
        }
        await cubit.close();
      });

    });

    group('endDrag', () {
      blocTest<ChromixCubit, ChromixState>(
        'clears drag state',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          for (var r = 0; r < ChromixGrid.size; r++) {
            for (var c = 0; c < ChromixGrid.size; c++) {
              final cell = cubit.state.grid.cellAt(r, c);
              if (cell is ColorCell && cell.color.isPrimary) {
                cubit
                  ..startDrag(r, c)
                  ..endDrag();
                return;
              }
            }
          }
        },
        verify: (cubit) {
          expect(cubit.state.dragOrigin, isNull);
          expect(cubit.state.dragColor, isNull);
        },
      );
    });

    group('overpower', () {
      test('mix then timer fires overpowers to dragged primary',
          () async {
        final cubit = ChromixCubit(dailySeed: mixSeed, dateKey: dateKey);
        await _waitForReady(cubit);

        final pair = _adjacentDifferentPrimaries(cubit.state.grid);
        expect(pair, isNotNull, reason: 'No adjacent different primaries');

        final dragColor =
            (cubit.state.grid.cellAt(pair!.row1, pair.col1)
                    as ColorCell)
                .color;
        final targetColor =
            (cubit.state.grid.cellAt(pair.row2, pair.col2)
                    as ColorCell)
                .color;
        final mixed = ColorMixer.mix(dragColor, targetColor);

        cubit
          ..startDrag(pair.row1, pair.col1)
          ..dragTo(pair.row2, pair.col2);

        // After mix, cell should be the mixed color.
        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(mixed),
        );

        // Wait for overpower timer.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // After overpower, cell should be the dragged primary.
        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(dragColor),
        );
        // Two moves: mix + overpower.
        expect(cubit.state.moveCount, equals(2));

        await cubit.close();
      });

      test('lifting finger before timer keeps mix result', () async {
        final cubit = ChromixCubit(dailySeed: mixSeed, dateKey: dateKey);
        await _waitForReady(cubit);

        final pair = _adjacentDifferentPrimaries(cubit.state.grid);
        expect(pair, isNotNull, reason: 'No adjacent different primaries');

        final dragColor =
            (cubit.state.grid.cellAt(pair!.row1, pair.col1)
                    as ColorCell)
                .color;
        final targetColor =
            (cubit.state.grid.cellAt(pair.row2, pair.col2)
                    as ColorCell)
                .color;
        final mixed = ColorMixer.mix(dragColor, targetColor);

        cubit
          ..startDrag(pair.row1, pair.col1)
          ..dragTo(pair.row2, pair.col2)
          ..endDrag(); // Lift before timer.

        // Wait a bit to make sure timer doesn't fire.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(mixed),
        );
        expect(cubit.state.moveCount, equals(1));

        await cubit.close();
      });

      test('overpower undo restores mix then restores original',
          () async {
        final cubit = ChromixCubit(dailySeed: mixSeed, dateKey: dateKey);
        await _waitForReady(cubit);

        final pair = _adjacentDifferentPrimaries(cubit.state.grid);
        expect(pair, isNotNull, reason: 'No adjacent different primaries');

        final originalColor =
            (cubit.state.grid.cellAt(pair!.row2, pair.col2)
                    as ColorCell)
                .color;
        final dragColor =
            (cubit.state.grid.cellAt(pair.row1, pair.col1)
                    as ColorCell)
                .color;
        final mixed = ColorMixer.mix(dragColor, originalColor);

        cubit
          ..startDrag(pair.row1, pair.col1)
          ..dragTo(pair.row2, pair.col2);

        // Wait for overpower.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // Undo overpower → should be mixed color.
        cubit.undo();
        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(mixed),
        );

        // Undo mix → should be original color.
        cubit.undo();
        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(originalColor),
        );

        await cubit.close();
      });

      test('drag onto secondary cell is no-op (locked)', () async {
        final cubit = ChromixCubit(dailySeed: mixSeed, dateKey: dateKey);
        await _waitForReady(cubit);

        // Create a secondary by mixing two adjacent primaries.
        final pair = _adjacentDifferentPrimaries(cubit.state.grid);
        expect(pair, isNotNull, reason: 'No adjacent different primaries');

        cubit
          ..startDrag(pair!.row1, pair.col1)
          ..dragTo(pair.row2, pair.col2)
          ..endDrag();

        final mixedCell =
            cubit.state.grid.cellAt(pair.row2, pair.col2);
        expect(mixedCell, isA<ColorCell>());
        expect((mixedCell as ColorCell).color.isSecondary, isTrue);

        // Now try to drag a primary onto the secondary — should be
        // no-op because secondaries are locked.
        final adjPrimary = _adjacentPrimaryCell(
          cubit.state.grid,
          pair.row2,
          pair.col2,
        );
        if (adjPrimary == null) {
          await cubit.close();
          return; // No adjacent primary to test with.
        }

        final movesBefore = cubit.state.moveCount;
        cubit
          ..startDrag(adjPrimary.$1, adjPrimary.$2)
          ..dragTo(pair.row2, pair.col2)
          ..endDrag();

        // Cell should still be the secondary — unchanged.
        expect(
          (cubit.state.grid.cellAt(pair.row2, pair.col2)
                  as ColorCell)
              .color,
          equals(mixedCell.color),
        );
        expect(cubit.state.moveCount, equals(movesBefore));

        await cubit.close();
      });
    });

    group('undo', () {
      blocTest<ChromixCubit, ChromixState>(
        'reverts last move and increments undoCount',
        build: () => ChromixCubit(dailySeed: seed, dateKey: dateKey),
        act: (cubit) async {
          await _waitForReady(cubit);
          final pair = _primaryWithAdjacentEmpty(cubit.state.grid);
          if (pair == null) return;
          cubit
            ..startDrag(pair.row, pair.col)
            ..dragTo(pair.emptyRow, pair.emptyCol)
            ..endDrag()
            ..undo();
        },
        verify: (cubit) {
          final pair = _primaryWithAdjacentEmpty(
            PuzzleGenerator.generate(seed).puzzle,
          );
          if (pair == null) return;
          expect(
            cubit.state.grid.cellAt(pair.emptyRow, pair.emptyCol),
            isA<EmptyCell>(),
          );
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
      test('puzzle is solvable by construction', () async {
        final result = PuzzleGenerator.generate(seed);
        final solveResult = PuzzleSolver.solve(
          grid: result.puzzle,
          target: result.target,
        );
        expect(solveResult.isUnique, isTrue);
      });

      test('single drag move keeps status as playing', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        final pair = _primaryWithAdjacentEmpty(cubit.state.grid);
        expect(pair, isNotNull, reason: 'seed $seed has no drag target');

        cubit
          ..startDrag(pair!.row, pair.col)
          ..dragTo(pair.emptyRow, pair.emptyCol)
          ..endDrag();
        expect(cubit.state.moveCount, equals(1));
        expect(cubit.state.status, equals(ChromixStatus.playing));

        await cubit.close();
      });
    });

    group('hasContiguityViolation', () {
      test('initially false', () async {
        final cubit = ChromixCubit(dailySeed: seed, dateKey: dateKey);
        await _waitForReady(cubit);

        expect(cubit.state.hasContiguityViolation, isFalse);

        await cubit.close();
      });

      test('true when a color at target count is non-contiguous',
          () {
        // Directly test the logic function from contiguity_checker.
        // Grid with 2 red cells separated by a blocker:
        //   R . # R
        //   # # # #
        //   # # # #
        //   # # # #
        final grid = ChromixGrid(
          cells: [
            const ColorCell(ChromixColor.red),
            const EmptyCell(),
            const BlockerCell(),
            const ColorCell(ChromixColor.red),
            ...List.filled(12, const BlockerCell()),
          ],
        );
        final target = <ChromixColor, int>{
          ChromixColor.red: 2,
        };
        expect(hasContiguityViolation(grid, target), isTrue);
      });

      test('false when color at target count is contiguous', () {
        // Two adjacent reds.
        final grid = ChromixGrid(
          cells: [
            const ColorCell(ChromixColor.red),
            const ColorCell(ChromixColor.red),
            ...List.filled(14, const BlockerCell()),
          ],
        );
        final target = <ChromixColor, int>{
          ChromixColor.red: 2,
        };
        expect(hasContiguityViolation(grid, target), isFalse);
      });
    });

    group('persistence', () {
      late GameStorageRepository storage;

      setUp(() {
        storage = _MockGameStorageRepository();
      });

      test('saves state after drag placement', () async {
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

        final pair = _primaryWithAdjacentEmpty(cubit.state.grid);
        if (pair != null) {
          cubit
            ..startDrag(pair.row, pair.col)
            ..dragTo(pair.emptyRow, pair.emptyCol)
            ..endDrag();

          verify(
            () => storage.saveSession(
              'chromix_state_$dateKey',
              any(that: isA<Map<String, dynamic>>()),
            ),
          ).called(1);
        }

        await cubit.close();
      });

      test('restores state from storage', () async {
        final realStorage = _RealStorageHelper();
        final cubit1 = ChromixCubit(
          dailySeed: seed,
          dateKey: dateKey,
          storageRepository: realStorage,
        );
        await _waitForReady(cubit1);
        final pair = _primaryWithAdjacentEmpty(cubit1.state.grid);
        if (pair != null) {
          cubit1
            ..startDrag(pair.row, pair.col)
            ..dragTo(pair.emptyRow, pair.emptyCol)
            ..endDrag();
        }
        final savedGrid = cubit1.state.grid;
        final savedMoveCount = cubit1.state.moveCount;
        await cubit1.close();

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
        // Drag state should not be restored.
        expect(cubit2.state.dragOrigin, isNull);
        expect(cubit2.state.dragColor, isNull);

        await cubit2.close();
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

        await cubit.close();
      });
    });
  });
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
