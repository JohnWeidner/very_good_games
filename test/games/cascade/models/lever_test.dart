import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('LeverDirection', () {
    test('opposite of left is right', () {
      expect(LeverDirection.left.opposite, LeverDirection.right);
    });

    test('opposite of right is left', () {
      expect(LeverDirection.right.opposite, LeverDirection.left);
    });
  });

  group('Lever', () {
    test('flip returns lever with opposite direction', () {
      const lever = Lever(
        row: 2,
        col: 3,
        direction: LeverDirection.left,
      );
      final flipped = lever.flip();

      expect(flipped.row, 2);
      expect(flipped.col, 3);
      expect(flipped.direction, LeverDirection.right);
    });

    test('double flip returns original', () {
      const lever = Lever(
        row: 1,
        col: 1,
        direction: LeverDirection.right,
      );
      expect(lever.flip().flip(), lever);
    });

    test('supports value equality', () {
      const a = Lever(row: 0, col: 0, direction: LeverDirection.left);
      const b = Lever(row: 0, col: 0, direction: LeverDirection.left);
      const c = Lever(row: 0, col: 0, direction: LeverDirection.right);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('serialization round-trip', () {
      const lever = Lever(
        row: 3,
        col: 4,
        direction: LeverDirection.right,
      );
      final json = lever.toJson();
      final restored = Lever.fromJson(json);

      expect(restored, lever);
    });
  });
}
