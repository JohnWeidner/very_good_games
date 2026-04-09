import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('BallId', () {
    test('has 3 values', () {
      expect(BallId.values.length, 3);
    });

    test('label returns correct number string', () {
      expect(BallId.ball1.label, '1');
      expect(BallId.ball2.label, '2');
      expect(BallId.ball3.label, '3');
    });

    test('indices are 0, 1, 2', () {
      expect(BallId.ball1.index, 0);
      expect(BallId.ball2.index, 1);
      expect(BallId.ball3.index, 2);
    });
  });
}
