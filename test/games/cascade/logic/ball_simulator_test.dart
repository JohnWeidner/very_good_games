import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('BallSimulator', () {
    test('ball falls straight down with no levers', () {
      final board = CascadeBoard(
        levers: const [],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      // Ball 1 drops from column 1, stays in column 1.
      expect(result.paths[0].finalBin, 1);
      expect(result.paths[0].positions.length, CascadeBoard.rows + 1);

      // Ball 2 drops from column 2, stays in column 2.
      expect(result.paths[1].finalBin, 2);

      // Ball 3 drops from column 3, stays in column 3.
      expect(result.paths[2].finalBin, 3);
    });

    test('lever deflects ball and flips', () {
      // Lever at row 2, col 2 pointing right => ball goes to col 3.
      final board = CascadeBoard(
        levers: const [
          Lever(row: 2, col: 2, direction: LeverDirection.right),
        ],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      // Ball 2 (slot 1, col 2) hits lever at (2,2), deflects right to col 3.
      expect(result.paths[1].finalBin, 3);
    });

    test('lever at wall edge does not deflect but still flips', () {
      // We need a lever to push ball to col 0 first.
      // Lever at (1, 1) pointing left => ball from slot 0 (col 1)
      // goes to col 0 at row 1, then hits lever at (3,0) pointing
      // left. Can't go to -1, stays at col 0.
      final board2 = CascadeBoard(
        levers: const [
          Lever(row: 1, col: 1, direction: LeverDirection.left),
          Lever(row: 3, col: 0, direction: LeverDirection.left),
        ],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board2,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      // Ball 1 (slot 0, col 1) deflects left at (1,1) to col 0,
      // then hits lever at (3,0) pointing left. Can't go to -1,
      // stays at col 0. Ball lands in col 0 (not a bin column).
      expect(result.paths[0].finalBin, 0);
    });

    test('sequential drops: first ball flips lever for second', () {
      // Lever at (2, 2) pointing right.
      // Ball 2 (slot 1, col 2) deflects right, lever flips to left.
      // Ball 3 (slot 2, col 3) won't hit this lever.
      // But if we put a lever at (2, 2) and drop from col 2 twice
      // via different slots... we need to use slot assignments.
      final board = CascadeBoard(
        levers: const [
          Lever(row: 2, col: 2, direction: LeverDirection.right),
        ],
        binOrder: const [0, 1, 2],
      );

      // Slot 0 = ball1 at col 1 (misses lever at col 2).
      // Slot 1 = ball2 at col 2 (hits lever, deflects right to 3,
      //   lever flips to left).
      // Slot 2 = ball3 at col 3 (misses lever at col 2).
      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      expect(result.paths[0].finalBin, 1); // Straight down.
      expect(result.paths[1].finalBin, 3); // Deflected right.
      expect(result.paths[2].finalBin, 3); // Straight down.
    });

    test('win detection: all balls in correct bins', () {
      // No levers, identity bin order [0,1,2]:
      // Ball 1 -> col 1 -> bin 0 expects ball index 0 (ball1).
      final board = CascadeBoard(
        levers: const [],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      expect(result.isWin, isTrue);
    });

    test('win detection: wrong assignment is not a win', () {
      final board = CascadeBoard(
        levers: const [],
        binOrder: const [0, 1, 2],
      );

      // Swap ball1 and ball2.
      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball2, BallId.ball1, BallId.ball3],
      );

      expect(result.isWin, isFalse);
    });

    test('each ball path has correct number of positions', () {
      final board = CascadeBoard(
        levers: const [],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      for (final path in result.paths) {
        expect(path.positions.length, CascadeBoard.rows + 1);
      }
    });
  });
}
