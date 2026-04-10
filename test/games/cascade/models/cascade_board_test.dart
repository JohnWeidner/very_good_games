import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('CascadeBoard', () {
    final levers = [
      const Lever(row: 1, col: 2, direction: LeverDirection.left),
      const Lever(row: 3, col: 1, direction: LeverDirection.right),
    ];
    final board = CascadeBoard(levers: levers, binOrder: const [2, 0, 1]);

    test('constants are correct', () {
      expect(CascadeBoard.columns, 5);
      expect(CascadeBoard.rows, 7);
      expect(CascadeBoard.dropSlotColumns, [1, 2, 3]);
    });

    test('flipLever returns board with flipped lever', () {
      final flipped = board.flipLever(0);

      expect(flipped.levers[0].direction, LeverDirection.right);
      // Other lever unchanged.
      expect(flipped.levers[1], board.levers[1]);
      // Bin order unchanged.
      expect(flipped.binOrder, board.binOrder);
    });

    test('resetLevers replaces all levers', () {
      final newLevers = [
        const Lever(row: 0, col: 0, direction: LeverDirection.right),
      ];
      final reset = board.resetLevers(newLevers);

      expect(reset.levers, newLevers);
      expect(reset.binOrder, board.binOrder);
    });

    test('supports value equality', () {
      final a = CascadeBoard(levers: levers, binOrder: const [2, 0, 1]);
      final b = CascadeBoard(levers: levers, binOrder: const [2, 0, 1]);
      final c = CascadeBoard(levers: levers, binOrder: const [0, 1, 2]);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('serialization round-trip', () {
      final json = board.toJson();
      final restored = CascadeBoard.fromJson(json);

      expect(restored, board);
    });

    test('levers list is unmodifiable', () {
      expect(
        () => board.levers.add(
          const Lever(row: 0, col: 0, direction: LeverDirection.left),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
