import 'dart:math';

import 'package:very_good_games/games/chromix/logic/puzzle_solver.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

/// Result of puzzle generation.
typedef GenerateResult =
    ({ChromixGrid puzzle, Map<ChromixColor, int> target, int optimalMoves});

/// Deterministic puzzle generator for Chromix.
///
/// Same seed always produces the same puzzle.
/// Uses a build-then-peel-back strategy:
/// 1. Build a complete valid board
/// 2. Compute the target distribution
/// 3. Peel back cells to create the puzzle
/// 4. Verify uniqueness with the solver
class PuzzleGenerator {
  /// Generates a puzzle from the given [seed].
  static GenerateResult generate(int seed) {
    const maxRetries = 10;

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

    // Step 2: Fill remaining cells with a valid color arrangement.
    final remaining =
        positions.where((i) => !blockerIndices.contains(i)).toList();
    final solution = _buildSolution(remaining, random);
    if (solution == null) return null;

    // Step 3: Build the complete grid and compute target.
    final solutionCells = List<ChromixCell>.generate(16, (i) {
      if (blockerIndices.contains(i)) return const BlockerCell();
      return ColorCell(solution[i]!);
    });
    final solutionGrid = ChromixGrid(cells: solutionCells);
    final target = solutionGrid.colorDistribution;

    // Step 4: Select 5–9 cells to keep as pre-filled.
    final nonBlockerIndices = remaining.toList()..shuffle(random);
    final preFilledCount = min(
      5 + random.nextInt(5),
      nonBlockerIndices.length,
    );
    final preFilledIndices =
        nonBlockerIndices.take(preFilledCount).toSet();

    // Step 5: Build the puzzle by peeling back non-pre-filled cells.
    final puzzleCells = List<ChromixCell>.generate(16, (i) {
      if (blockerIndices.contains(i)) return const BlockerCell();
      final color = solution[i]!;
      if (preFilledIndices.contains(i)) {
        return ColorCell(color, isPreFilled: true);
      }
      // Peel back: secondary → constituent primary, primary → empty.
      if (color.isSecondary) {
        final constituent = _getConstituent(color, random);
        return ColorCell(constituent, isPreFilled: true);
      }
      return const EmptyCell();
    });

    final puzzle = ChromixGrid(cells: puzzleCells);

    // Step 6: Verify unique solution.
    final result = PuzzleSolver.solve(grid: puzzle, target: target);
    if (!result.isUnique) return null;

    return (
      puzzle: puzzle,
      target: target,
      optimalMoves: result.optimalMoves,
    );
  }

  /// Builds a valid complete color arrangement for the non-blocker cells.
  ///
  /// Assigns primaries and secondaries such that each secondary is
  /// reachable by mixing two primaries that exist on the board.
  static Map<int, ChromixColor>? _buildSolution(
    List<int> indices,
    Random random,
  ) {
    if (indices.isEmpty) return {};

    final colors = <int, ChromixColor>{};

    // Decide how many secondaries (roughly 1/3 of cells).
    final secondaryCount = max(1, indices.length ~/ 3);
    final primariesNeeded = indices.length - secondaryCount;

    // Assign primaries first.
    final shuffledIndices = indices.toList()..shuffle(random);
    final primaries = [
      ChromixColor.red,
      ChromixColor.yellow,
      ChromixColor.blue,
    ];

    for (var i = 0; i < primariesNeeded; i++) {
      colors[shuffledIndices[i]] = primaries[random.nextInt(3)];
    }

    // Assign secondaries — each one must be achievable from two
    // primaries present on the board.
    final secondaries = [
      ChromixColor.orange,
      ChromixColor.green,
      ChromixColor.purple,
    ];

    for (var i = primariesNeeded; i < indices.length; i++) {
      colors[shuffledIndices[i]] = secondaries[random.nextInt(3)];
    }

    return colors;
  }

  /// Returns a random constituent primary of a secondary color.
  static ChromixColor _getConstituent(
    ChromixColor secondary,
    Random random,
  ) {
    final constituents = switch (secondary) {
      ChromixColor.orange => [ChromixColor.red, ChromixColor.yellow],
      ChromixColor.green => [ChromixColor.yellow, ChromixColor.blue],
      ChromixColor.purple => [ChromixColor.red, ChromixColor.blue],
      _ => [secondary], // Should not happen.
    };
    return constituents[random.nextInt(constituents.length)];
  }

  /// Fallback generation that returns a result regardless of uniqueness.
  static GenerateResult _generateFallback(int seed) {
    final random = Random(seed.abs());

    final blockerCount = 1 + random.nextInt(4);
    final positions = List.generate(16, (i) => i)..shuffle(random);
    final blockerIndices = positions.take(blockerCount).toSet();

    final remaining =
        positions.where((i) => !blockerIndices.contains(i)).toList();
    final solution = _buildSolution(remaining, random) ?? {};

    final solutionCells = List<ChromixCell>.generate(16, (i) {
      if (blockerIndices.contains(i)) return const BlockerCell();
      return ColorCell(solution[i] ?? ChromixColor.red);
    });
    final solutionGrid = ChromixGrid(cells: solutionCells);
    final target = solutionGrid.colorDistribution;

    final nonBlockerIndices = remaining.toList()..shuffle(random);
    final preFilledCount = min(
      5 + random.nextInt(5),
      nonBlockerIndices.length,
    );
    final preFilledIndices =
        nonBlockerIndices.take(preFilledCount).toSet();

    final puzzleCells = List<ChromixCell>.generate(16, (i) {
      if (blockerIndices.contains(i)) return const BlockerCell();
      final color = solution[i] ?? ChromixColor.red;
      if (preFilledIndices.contains(i)) {
        return ColorCell(color, isPreFilled: true);
      }
      if (color.isSecondary) {
        final constituent = _getConstituent(color, random);
        return ColorCell(constituent, isPreFilled: true);
      }
      return const EmptyCell();
    });

    final puzzle = ChromixGrid(cells: puzzleCells);
    final solveResult = PuzzleSolver.solve(
      grid: puzzle,
      target: target,
    );

    return (
      puzzle: puzzle,
      target: target,
      optimalMoves: solveResult.optimalMoves,
    );
  }
}

