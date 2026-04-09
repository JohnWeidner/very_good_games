import 'dart:math';

import 'package:very_good_games/games/cascade/logic/ball_simulator.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

/// Result of puzzle generation.
typedef CascadeGenerateResult = ({
  CascadeBoard board,
  List<Lever> initialLevers,
});

/// Deterministic puzzle generator for Cascade.
///
/// Same seed always produces the same puzzle. Uses generate-then-verify:
/// 1. Place 6-8 levers randomly on the grid
/// 2. Assign random initial directions and bin order
/// 3. Enumerate all possible configurations (6 permutations x 2^N lever states)
/// 4. Accept if exactly one configuration wins
/// 5. Retry with seed+1 if not unique
class PuzzleGenerator {
  /// Generates a puzzle from the given [seed].
  ///
  /// Runs in an isolate via `compute`.
  static CascadeGenerateResult generate(int seed) {
    const maxRetries = 100;
    CascadeGenerateResult? bestFallback;
    var fewestSolutions = 999;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final result = _tryGenerate(seed + attempt);
      if (result == null) continue;

      final (board, initialLevers, solutionCount) = result;

      if (solutionCount == 1) {
        return (board: board, initialLevers: initialLevers);
      }

      if (solutionCount < fewestSolutions && solutionCount > 0) {
        fewestSolutions = solutionCount;
        bestFallback = (board: board, initialLevers: initialLevers);
      }
    }

    // Fallback: return the puzzle with fewest solutions.
    return bestFallback ?? _generateFallback(seed);
  }

  static (CascadeBoard, List<Lever>, int)? _tryGenerate(int seed) {
    final random = Random(seed);

    // 1. Decide lever count (6-8).
    final leverCount = 6 + random.nextInt(3);

    // 2. Place levers on valid grid positions.
    //    Levers can go on rows 0-6, columns 0-4.
    //    Avoid placing multiple levers on the same cell.
    final positions = _generateLeverPositions(random, leverCount);
    if (positions == null) return null;

    // 3. Assign random initial directions.
    final levers = positions
        .map(
          (pos) => Lever(
            row: pos.$1,
            col: pos.$2,
            direction: random.nextBool()
                ? LeverDirection.left
                : LeverDirection.right,
          ),
        )
        .toList();

    // 4. Generate random bin order (permutation of [0, 1, 2]).
    final binOrder = [0, 1, 2]..shuffle(random);

    final board = CascadeBoard(levers: levers, binOrder: binOrder);
    final initialLevers = levers.toList();

    // 5. Enumerate all configurations and count solutions.
    final solutionCount = _countSolutions(board, leverCount);

    return (board, initialLevers, solutionCount);
  }

  /// Places [count] levers on distinct grid cells.
  ///
  /// Returns a list of (row, col) pairs, or null if placement failed.
  static List<(int, int)>? _generateLeverPositions(
    Random random,
    int count,
  ) {
    final allPositions = <(int, int)>[];
    // Start at row 1 — row 0 is the drop slot row where balls are
    // dragged, so placing levers there conflicts with drag targets.
    for (var row = 1; row < CascadeBoard.rows; row++) {
      for (var col = 0; col < CascadeBoard.columns; col++) {
        allPositions.add((row, col));
      }
    }

    allPositions.shuffle(random);
    if (allPositions.length < count) return null;
    return allPositions.sublist(0, count);
  }

  /// Counts the number of winning configurations.
  ///
  /// A configuration is a ball permutation (6 total) combined with
  /// a lever state (2^leverCount). For each, simulate the drop and
  /// check if all balls land correctly.
  static int _countSolutions(CascadeBoard board, int leverCount) {
    final permutations = _ballPermutations();
    final leverStateCount = 1 << leverCount; // 2^leverCount
    var solutions = 0;

    for (final perm in permutations) {
      for (var leverMask = 0; leverMask < leverStateCount; leverMask++) {
        // Build a board with this specific lever configuration.
        final testBoard = _boardWithLeverMask(board, leverMask);

        final result = BallSimulator.simulate(
          board: testBoard,
          slotAssignments: perm,
        );

        if (result.isWin) solutions++;
      }
    }

    return solutions;
  }

  /// Returns all 6 permutations of [BallId.ball1, ball2, ball3].
  static List<List<BallId>> _ballPermutations() {
    const balls = BallId.values;
    final perms = <List<BallId>>[];

    for (var i = 0; i < balls.length; i++) {
      for (var j = 0; j < balls.length; j++) {
        if (j == i) continue;
        for (var k = 0; k < balls.length; k++) {
          if (k == i || k == j) continue;
          perms.add([balls[i], balls[j], balls[k]]);
        }
      }
    }

    return perms;
  }

  /// Returns a board with lever directions set from a bitmask.
  ///
  /// Bit `i` of [mask] determines lever `i`: 0 = left, 1 = right.
  static CascadeBoard _boardWithLeverMask(CascadeBoard board, int mask) {
    final newLevers = <Lever>[];
    for (var i = 0; i < board.levers.length; i++) {
      final direction =
          (mask >> i) & 1 == 0 ? LeverDirection.left : LeverDirection.right;
      final lever = board.levers[i];
      newLevers.add(
        Lever(row: lever.row, col: lever.col, direction: direction),
      );
    }
    return CascadeBoard(levers: newLevers, binOrder: board.binOrder);
  }

  /// Last-resort fallback that generates a simple valid puzzle.
  static CascadeGenerateResult _generateFallback(int seed) {
    final random = Random(seed);
    const levers = [
      Lever(row: 1, col: 2, direction: LeverDirection.left),
      Lever(row: 2, col: 1, direction: LeverDirection.right),
      Lever(row: 3, col: 3, direction: LeverDirection.left),
      Lever(row: 4, col: 2, direction: LeverDirection.right),
      Lever(row: 5, col: 1, direction: LeverDirection.left),
      Lever(row: 5, col: 3, direction: LeverDirection.right),
    ];
    final binOrder = [0, 1, 2]..shuffle(random);
    final board = CascadeBoard(levers: levers, binOrder: binOrder);
    return (board: board, initialLevers: levers.toList());
  }
}
