import 'dart:collection';
import 'dart:math';

import 'package:very_good_games/games/chromix/logic/color_mixer.dart';
import 'package:very_good_games/games/chromix/logic/contiguity_checker.dart';
import 'package:very_good_games/games/chromix/logic/puzzle_solver.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

/// Result of puzzle generation.
typedef GenerateResult =
    ({ChromixGrid puzzle, Map<ChromixColor, int> target, int optimalMoves});

/// Deterministic puzzle generator for Chromix.
///
/// Same seed always produces the same puzzle.
/// Uses forward generation:
/// 1. Place blockers and seed cells (all 6 colors or 5)
/// 2. Simulate valid drag moves until the grid is fully filled,
///    never eliminating the last cell of any color
/// 3. The filled grid's distribution becomes the target
/// 4. The seed cells become the starting puzzle
/// 5. Verify uniqueness with the solver
///
/// This guarantees the target is always reachable from the starting
/// state via drag moves, since it was built that way.
class PuzzleGenerator {
  /// Generates a puzzle from the given [seed].
  static GenerateResult generate(int seed) {
    const maxRetries = 30;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final result = _tryGenerate(seed + attempt);
      if (result != null) return result;
    }

    // Fallback: use the last attempt's result even if not unique.
    return _generateFallback(seed + maxRetries - 1);
  }

  static GenerateResult? _tryGenerate(int seed) {
    final random = Random(seed.abs());

    // Step 1: Place 1–4 blockers.
    final blockerCount = 1 + random.nextInt(4);
    final positions = List.generate(16, (i) => i)..shuffle(random);
    final blockerIndices = positions.take(blockerCount).toSet();

    // Step 2: Validate non-blocker cells form a single connected component.
    final nonBlockerIndices =
        positions.where((i) => !blockerIndices.contains(i)).toList();
    if (!_isConnected(nonBlockerIndices)) return null;

    // Need enough cells for at least 5 seed colors + room to fill.
    if (nonBlockerIndices.length < 8) return null;

    // Step 3: Place seed cells with 5–6 colors.
    final startGrid = _buildStartGrid(
      nonBlockerIndices,
      blockerIndices,
      random,
    );
    if (startGrid == null) return null;

    // Verify we have at least 5 distinct colors on the start grid.
    final startColors = <ChromixColor>{};
    for (final cell in startGrid.cells) {
      if (cell is ColorCell) startColors.add(cell.color);
    }
    if (startColors.length < 5) return null;

    // Step 4: Simulate valid drag moves until fully filled.
    final filledGrid = _simulateMoves(startGrid, random);
    if (filledGrid == null) return null;

    // Step 5: Verify target has at least 5 colors and contiguous groups.
    final target = filledGrid.colorDistribution;
    if (target.length < 5) return null;
    if (!allGroupsContiguous(filledGrid)) return null;

    // Step 6: Verify unique solution.
    final solveResult = PuzzleSolver.solve(grid: startGrid, target: target);
    if (!solveResult.isUnique) return null;

    return (
      puzzle: startGrid,
      target: target,
      optimalMoves: solveResult.optimalMoves,
    );
  }

  /// Builds a starting grid with all 3 primaries placed, then creates
  /// 2–3 secondaries by mixing adjacent primary pairs.
  ///
  /// Returns the grid with 5–6 distinct colors, or null if placement fails.
  static ChromixGrid? _buildStartGrid(
    List<int> nonBlockerIndices,
    Set<int> blockerIndices,
    Random random,
  ) {
    const size = ChromixGrid.size;
    const primaries = [
      ChromixColor.red,
      ChromixColor.yellow,
      ChromixColor.blue,
    ];

    final shuffled = nonBlockerIndices.toList()..shuffle(random);

    // Place 2 of each primary (6 cells) to ensure we have enough to mix.
    // Round-robin: R, Y, B, R, Y, B.
    final primaryCount = min(6, shuffled.length);
    if (primaryCount < 6) return null;

    final assignment = <int, ChromixColor>{};
    for (var i = 0; i < primaryCount; i++) {
      assignment[shuffled[i]] = primaries[i % primaries.length];
    }

    // Build a mutable cells list.
    final cells = List<ChromixCell>.generate(16, (i) {
      if (blockerIndices.contains(i)) return const BlockerCell();
      if (assignment.containsKey(i)) {
        return ColorCell(assignment[i]!, isPreFilled: true);
      }
      return const EmptyCell();
    });

    // Now create secondaries by mixing adjacent primary pairs.
    // Try to create 2–3 distinct secondaries. Each secondary color
    // is created at most once to avoid disconnected same-color groups
    // that the player cannot connect (secondaries can't be dragged).
    final targetSecondaryCount = 2 + random.nextInt(2); // 2 or 3
    var secondariesCreated = 0;
    final usedSecondaries = <ChromixColor>{};

    // Shuffle cell indices to randomize which pairs we try.
    final cellIndices = List.generate(16, (i) => i)..shuffle(random);

    for (final i in cellIndices) {
      if (secondariesCreated >= targetSecondaryCount) break;

      final cell = cells[i];
      if (cell is! ColorCell || !cell.color.isPrimary) continue;

      final row = i ~/ size;
      final col = i % size;
      final neighbors = _neighbors(row, col, size)..shuffle(random);

      for (final n in neighbors) {
        final neighbor = cells[n];
        if (neighbor is! ColorCell || !neighbor.color.isPrimary) continue;
        if (neighbor.color == cell.color) continue;

        final mixed = ColorMixer.mix(cell.color, neighbor.color);
        if (mixed == null) continue;

        // Skip if we already placed this secondary color.
        if (usedSecondaries.contains(mixed)) continue;

        // Check that mixing won't eliminate the last cell of the
        // target's color.
        final targetColor = neighbor.color;
        final targetColorCount = cells
            .whereType<ColorCell>()
            .where((c) => c.color == targetColor)
            .length;
        if (targetColorCount <= 1) continue;

        // Place the secondary.
        final nRow = n ~/ size;
        final nCol = n % size;
        cells[nRow * size + nCol] = ColorCell(mixed, isPreFilled: true);
        usedSecondaries.add(mixed);
        secondariesCreated++;
        break;
      }
    }

    if (secondariesCreated < 2) return null;

    final grid = ChromixGrid(cells: cells);

    // Verify no primary is stranded. Every primary cell must be able
    // to reach at least one empty cell or another cell of the same
    // color via orthogonal steps through empty or same-primary cells.
    // A primary surrounded entirely by blockers, secondaries, and
    // different primaries with no empty neighbor can never grow or
    // connect, making the puzzle unsolvable.
    if (!_allPrimariesCanGrow(grid)) return null;

    return grid;
  }

  /// Returns false if any primary color with multiple cells on the
  /// grid has an instance that is completely isolated — unable to
  /// reach an empty cell or another cell of the same color.
  ///
  /// A primary that is the only instance of its color is allowed
  /// to be isolated, since the target can just need exactly one.
  static bool _allPrimariesCanGrow(ChromixGrid grid) {
    const size = ChromixGrid.size;

    // Count how many cells of each primary color exist.
    final colorCounts = <ChromixColor, int>{};
    for (final cell in grid.cells) {
      if (cell is ColorCell && cell.color.isPrimary) {
        colorCounts[cell.color] = (colorCounts[cell.color] ?? 0) + 1;
      }
    }

    for (var i = 0; i < grid.cells.length; i++) {
      final cell = grid.cells[i];
      if (cell is! ColorCell || !cell.color.isPrimary) continue;

      // If this is the only cell of its color, isolation is fine.
      if ((colorCounts[cell.color] ?? 0) <= 1) continue;

      final color = cell.color;

      // BFS: can this cell reach an empty cell or another same-color
      // cell via adjacent empty cells?
      var canGrow = false;
      final visited = <int>{i};
      final queue = [i];

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        final r = current ~/ size;
        final c = current % size;

        for (final n in _neighbors(r, c, size)) {
          if (visited.contains(n)) continue;
          final nc = grid.cells[n];
          if (nc is EmptyCell) {
            canGrow = true;
            break;
          }
          if (nc is ColorCell && nc.color == color) {
            canGrow = true;
            break;
          }
        }
        if (canGrow) break;

        // Expand through empty cells (reachable path).
        for (final n in _neighbors(r, c, size)) {
          if (visited.contains(n)) continue;
          final nc = grid.cells[n];
          if (nc is EmptyCell) {
            visited.add(n);
            queue.add(n);
          }
        }
      }

      if (!canGrow) return false;
    }

    return true;
  }

  /// Simulates random valid drag moves from [grid] until fully filled.
  ///
  /// Never makes a move that would eliminate the last cell of any color.
  /// Returns the filled grid, or null if the simulation gets stuck.
  static ChromixGrid? _simulateMoves(ChromixGrid grid, Random random) {
    var current = grid;
    const maxSteps = 100; // Safety limit.

    for (var step = 0; step < maxSteps; step++) {
      if (current.isFullyFilled) return current;

      // Collect all valid drag actions.
      final actions = _validActions(current);
      if (actions.isEmpty) return null; // Stuck.

      // Pick a random action and apply it.
      final action = actions[random.nextInt(actions.length)];
      current = _applyAction(current, action);
    }

    return current.isFullyFilled ? current : null;
  }

  /// Collects valid drag actions, excluding any mix that would eliminate
  /// the last cell of the target color.
  static List<_DragAction> _validActions(ChromixGrid grid) {
    const size = ChromixGrid.size;

    // Pre-compute color counts for the elimination check.
    final colorCounts = <ChromixColor, int>{};
    for (final cell in grid.cells) {
      if (cell is ColorCell) {
        colorCounts[cell.color] = (colorCounts[cell.color] ?? 0) + 1;
      }
    }

    final actions = <_DragAction>[];

    for (var i = 0; i < grid.cells.length; i++) {
      final cell = grid.cells[i];
      if (cell is! ColorCell || !cell.color.isPrimary) continue;

      final row = i ~/ size;
      final col = i % size;

      for (final n in _neighbors(row, col, size)) {
        final neighbor = grid.cells[n];
        switch (neighbor) {
          case EmptyCell():
            actions.add(_DragAction(i, n, _ActionType.spread));
          case ColorCell(color: final nc):
            if (nc.isPrimary && nc != cell.color) {
              // Only allow the mix if it won't eliminate the last
              // cell of the target color.
              if ((colorCounts[nc] ?? 0) > 1) {
                actions.add(_DragAction(i, n, _ActionType.mix));
              }
            }
          case BlockerCell():
            break;
        }
      }
    }

    return actions;
  }

  /// Applies a drag action to the grid, returning the new grid.
  static ChromixGrid _applyAction(ChromixGrid grid, _DragAction action) {
    const size = ChromixGrid.size;
    final sourceCell = grid.cells[action.sourceIdx] as ColorCell;
    final targetRow = action.targetIdx ~/ size;
    final targetCol = action.targetIdx % size;

    switch (action.type) {
      case _ActionType.spread:
        return grid.setCell(
          targetRow,
          targetCol,
          ColorCell(sourceCell.color),
        );
      case _ActionType.mix:
        final targetCell = grid.cells[action.targetIdx] as ColorCell;
        final mixed = ColorMixer.mix(sourceCell.color, targetCell.color);
        if (mixed == null) return grid;
        return grid.setCell(targetRow, targetCol, ColorCell(mixed));
    }
  }

  /// Checks that non-blocker cells form a single connected component.
  static bool _isConnected(List<int> indices) {
    if (indices.length <= 1) return true;

    const size = ChromixGrid.size;
    final indexSet = indices.toSet();
    final visited = <int>{indices.first};
    final queue = Queue<int>()..add(indices.first);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final row = current ~/ size;
      final col = current % size;

      for (final neighbor in _neighbors(row, col, size)) {
        if (indexSet.contains(neighbor) && visited.add(neighbor)) {
          queue.add(neighbor);
        }
      }
    }

    return visited.length == indices.length;
  }

  static List<int> _neighbors(int row, int col, int size) {
    final result = <int>[];
    if (row > 0) result.add((row - 1) * size + col);
    if (row < size - 1) result.add((row + 1) * size + col);
    if (col > 0) result.add(row * size + (col - 1));
    if (col < size - 1) result.add(row * size + (col + 1));
    return result;
  }

  /// Fallback generation that returns a result regardless of uniqueness.
  static GenerateResult _generateFallback(int seed) {
    for (var attempt = 0; attempt < 50; attempt++) {
      final random = Random((seed + attempt).abs());

      final blockerCount = 1 + random.nextInt(4);
      final positions = List.generate(16, (i) => i)..shuffle(random);
      final blockerIndices = positions.take(blockerCount).toSet();

      final nonBlockerIndices =
          positions.where((i) => !blockerIndices.contains(i)).toList();
      if (nonBlockerIndices.length < 8) continue;

      final startGrid = _buildStartGrid(
        nonBlockerIndices,
        blockerIndices,
        random,
      );
      if (startGrid == null) continue;

      final filledGrid = _simulateMoves(startGrid, random);
      if (filledGrid == null) continue;

      final target = filledGrid.colorDistribution;
      if (target.length < 5) continue;

      final solveResult = PuzzleSolver.solve(
        grid: startGrid,
        target: target,
      );

      return (
        puzzle: startGrid,
        target: target,
        optimalMoves: solveResult.optimalMoves,
      );
    }

    // Last resort: a trivial 1-blocker, 15-cell all-red puzzle.
    final cells = [
      const BlockerCell(),
      ...List.filled(
        15,
        const ColorCell(ChromixColor.red, isPreFilled: true),
      ),
    ];
    final grid = ChromixGrid(cells: cells);
    return (
      puzzle: grid,
      target: grid.colorDistribution,
      optimalMoves: 0,
    );
  }
}

enum _ActionType { spread, mix }

class _DragAction {
  const _DragAction(this.sourceIdx, this.targetIdx, this.type);

  final int sourceIdx;
  final int targetIdx;
  final _ActionType type;
}
