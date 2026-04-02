import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

void main() {
  group('CellState', () {
    test('has all expected values', () {
      expect(CellState.values, hasLength(4));
      expect(
        CellState.values,
        containsAll([
          CellState.possible,
          CellState.eliminated,
          CellState.wrongGuess,
          CellState.target,
        ]),
      );
    });
  });
}
