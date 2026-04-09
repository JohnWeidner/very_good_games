import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('BallPath', () {
    test('supports value equality', () {
      const a = BallPath(
        ballId: BallId.ball1,
        positions: [(row: 0, col: 1), (row: 1, col: 1)],
        finalBin: 1,
      );
      const b = BallPath(
        ballId: BallId.ball1,
        positions: [(row: 0, col: 1), (row: 1, col: 1)],
        finalBin: 1,
      );
      const c = BallPath(
        ballId: BallId.ball2,
        positions: [(row: 0, col: 1), (row: 1, col: 1)],
        finalBin: 1,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('DropResult', () {
    test('supports value equality', () {
      const paths = [
        BallPath(
          ballId: BallId.ball1,
          positions: [(row: 0, col: 1)],
          finalBin: 1,
        ),
      ];
      const a = DropResult(paths: paths, isWin: true);
      const b = DropResult(paths: paths, isWin: true);
      const c = DropResult(paths: paths, isWin: false);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
