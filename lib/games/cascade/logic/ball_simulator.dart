import 'package:very_good_games/games/cascade/models/models.dart';

/// Pure simulation engine for the Cascade ball-routing puzzle.
///
/// Given a board and ball-to-slot assignments, computes the path each
/// ball takes through the grid. Balls are dropped sequentially (slot 0,
/// 1, 2), and each ball flips the levers it passes through, changing
/// the path for subsequent balls.
class BallSimulator {
  /// Simulates all 3 balls dropping through the board.
  ///
  /// [slotAssignments] maps each drop slot (index 0, 1, 2)
  /// to the [BallId] assigned to that slot.
  ///
  /// Returns a [DropResult] with each ball's path and whether
  /// all balls reached their correct target bins.
  static DropResult simulate({
    required CascadeBoard board,
    required List<BallId> slotAssignments,
  }) {
    var currentBoard = board;
    final paths = <BallPath>[];

    // Drop in ball-ID order: ball1 first, ball2 second, ball3 third.
    // The slot assignment determines WHERE each ball drops from.
    for (final ballId in BallId.values) {
      final slot = slotAssignments.indexOf(ballId);
      final startCol = CascadeBoard.dropSlotColumns[slot];

      final (path, updatedBoard) = _simulateBall(
        board: currentBoard,
        ballId: ballId,
        startCol: startCol,
      );

      paths.add(path);
      currentBoard = updatedBoard;
    }

    // Check if all balls landed in correct bins.
    final isWin = _checkWin(paths, board.binOrder);

    return DropResult(paths: paths, isWin: isWin);
  }

  /// Simulates a single ball dropping from [startCol] through the board.
  ///
  /// Returns the ball's path and the board with mutated lever states.
  static (BallPath, CascadeBoard) _simulateBall({
    required CascadeBoard board,
    required BallId ballId,
    required int startCol,
  }) {
    var currentBoard = board;
    final positions = <BoardPosition>[];
    final leverFlips = <LeverFlip>[];
    final wallBounces = <int>{};
    var col = startCol;

    // Record entry position (above the board, at row -1 conceptually,
    // but we start tracking from row 0).
    for (var row = 0; row < CascadeBoard.rows; row++) {
      positions.add((row: row, col: col));

      // Check for a lever at this position.
      final leverIndex = _leverIndexAt(currentBoard, row, col);
      if (leverIndex != null) {
        final lever = currentBoard.levers[leverIndex];
        final targetCol =
            col + (lever.direction == LeverDirection.left ? -1 : 1);

        // Record lever flip at the arrival position (the ball just
        // landed on the lever), so the lever reacts at the same
        // instant the ball starts its bounce/deflection.
        final arrivalIndex = positions.length - 1;
        currentBoard = currentBoard.flipLever(leverIndex);
        leverFlips.add(
          (leverIndex: leverIndex, step: arrivalIndex),
        );

        if (targetCol >= 0 && targetCol < CascadeBoard.columns) {
          // Successful deflection: slide horizontally.
          col = targetCol;
          positions.add((row: row, col: col));
        } else {
          // Wall bounce: ball moves toward the edge, hits the wall,
          // and returns to the same column. Two intermediate
          // positions at the same (row, col) let the view animate
          // the outward-and-back arc. The bounce starts from the
          // arrival position (last added), so record that index.
          wallBounces.add(arrivalIndex);
          positions
            ..add((row: row, col: col))
            ..add((row: row, col: col));
        }
      }
    }

    // Add final position in the bin row (one past the grid).
    positions.add((row: CascadeBoard.rows, col: col));

    // Add bin bounce positions: 3 bounces, each is 2 segments
    // (up to peak, back down). All at the same grid position —
    // the view handles vertical displacement.
    final binBounceStart = positions.length - 1;
    const bounceCount = 4;
    for (var i = 0; i < bounceCount; i++) {
      // Peak position + return to bottom (same grid cell,
      // view handles vertical displacement).
      positions
        ..add((row: CascadeBoard.rows, col: col))
        ..add((row: CascadeBoard.rows, col: col));
    }

    // Determine which bin the ball landed in.
    // Bins are at columns 1, 2, 3 (same as drop slots).
    final finalBin = col;

    return (
      BallPath(
        ballId: ballId,
        positions: positions,
        finalBin: finalBin,
        leverFlips: leverFlips,
        wallBounces: wallBounces,
        binBounceStart: binBounceStart,
      ),
      currentBoard,
    );
  }

  /// Returns the index of the lever at ([row], [col]), or null.
  static int? _leverIndexAt(CascadeBoard board, int row, int col) {
    for (var i = 0; i < board.levers.length; i++) {
      if (board.levers[i].row == row && board.levers[i].col == col) {
        return i;
      }
    }
    return null;
  }

  /// Checks whether all balls landed in the correct target bins.
  ///
  /// Ball at slot `i` should land in the bin where `binOrder[binIndex] == i`.
  /// Since balls are mapped by BallId (ball1=0, ball2=1, ball3=2),
  /// the ball in bin column `dropSlotColumns[j]` is correct if
  /// `binOrder[j] == ball.index`.
  static bool _checkWin(List<BallPath> paths, List<int> binOrder) {
    for (final path in paths) {
      final binCol = path.finalBin;

      // Find which bin position this column corresponds to.
      final binIndex = CascadeBoard.dropSlotColumns.indexOf(binCol);
      if (binIndex == -1) {
        // Ball didn't land in a bin column — always wrong.
        return false;
      }

      // Check if this ball is the one expected at this bin.
      if (binOrder[binIndex] != path.ballId.index) {
        return false;
      }
    }
    return true;
  }
}
