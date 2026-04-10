import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('BallSimulator', () {
    test('ball falls straight down with no levers', () {
      final board = CascadeBoard(levers: const [], binOrder: const [0, 1, 2]);

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      expect(result.paths[0].finalBin, 1);
      // 7 rows + 1 bin + 8 bin bounces, no deflections.
      expect(result.paths[0].positions.length, CascadeBoard.rows + 9);
      expect(result.paths[0].leverFlips, isEmpty);
      expect(result.paths[0].wallBounces, isEmpty);

      expect(result.paths[1].finalBin, 2);
      expect(result.paths[2].finalBin, 3);
    });

    test('lever deflects ball and records leverFlip', () {
      final board = CascadeBoard(
        levers: const [Lever(row: 2, col: 2, direction: LeverDirection.right)],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      // Ball 2 hits lever at (2,2), deflects right to col 3.
      expect(result.paths[1].finalBin, 3);
      expect(result.paths[1].leverFlips, hasLength(1));
      expect(result.paths[1].leverFlips[0].leverIndex, 0);
      // Step is the position index where the ball reaches the lever row.
      expect(result.paths[1].leverFlips[0].step, 2);

      // Deflection adds an intermediate position.
      // 7 rows + 1 bin + 1 intermediate + 8 bin bounces = 17.
      expect(result.paths[1].positions.length, CascadeBoard.rows + 10);
    });

    test('wall bounce records wallBounces and extra positions', () {
      // Lever at (1,1) pushes ball to col 0, then lever at (3,0)
      // points left — blocked by wall, should wall-bounce.
      final board = CascadeBoard(
        levers: const [
          Lever(row: 1, col: 1, direction: LeverDirection.left),
          Lever(row: 3, col: 0, direction: LeverDirection.left),
        ],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      final path = result.paths[0];
      expect(path.finalBin, 0);

      // 2 lever hits: one deflection (+1 intermediate) and one
      // wall bounce (+2 intermediates).
      expect(path.leverFlips, hasLength(2));
      expect(path.wallBounces, hasLength(1));

      // 7 rows + 1 bin + 1 deflection + 2 wall bounce + 8 bin bounces = 19.
      expect(path.positions.length, CascadeBoard.rows + 12);
    });

    test('sequential drops: first ball flips lever for second', () {
      final board = CascadeBoard(
        levers: const [Lever(row: 2, col: 2, direction: LeverDirection.right)],
        binOrder: const [0, 1, 2],
      );

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      expect(result.paths[0].finalBin, 1);
      expect(result.paths[1].finalBin, 3);
      expect(result.paths[2].finalBin, 3);
    });

    test('win detection: all balls in correct bins', () {
      final board = CascadeBoard(levers: const [], binOrder: const [0, 1, 2]);

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      expect(result.isWin, isTrue);
    });

    test('win detection: wrong assignment is not a win', () {
      final board = CascadeBoard(levers: const [], binOrder: const [0, 1, 2]);

      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball2, BallId.ball1, BallId.ball3],
      );

      expect(result.isWin, isFalse);
    });

    test('drops in ball-ID order regardless of slot assignment', () {
      final board = CascadeBoard(levers: const [], binOrder: const [0, 1, 2]);

      // Assign ball3 to slot 0, ball1 to slot 1, ball2 to slot 2.
      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball3, BallId.ball1, BallId.ball2],
      );

      // Drop order is always ball1, ball2, ball3.
      expect(result.paths[0].ballId, BallId.ball1);
      expect(result.paths[1].ballId, BallId.ball2);
      expect(result.paths[2].ballId, BallId.ball3);
    });
  });
}
