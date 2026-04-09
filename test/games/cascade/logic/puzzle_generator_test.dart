import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

void main() {
  group('PuzzleGenerator', () {
    test('same seed produces identical puzzle (determinism)', () {
      const seed = 42;
      final result1 = PuzzleGenerator.generate(seed);
      final result2 = PuzzleGenerator.generate(seed);

      expect(result1.board, equals(result2.board));
      expect(result1.initialLevers, equals(result2.initialLevers));
    });

    test('different seeds produce different puzzles', () {
      final result1 = PuzzleGenerator.generate(100);
      final result2 = PuzzleGenerator.generate(200);

      // Very unlikely to be the same.
      expect(result1.board, isNot(equals(result2.board)));
    });

    test('generated board has 6-8 levers', () {
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        expect(
          result.board.levers.length,
          inInclusiveRange(6, 8),
          reason: 'seed=$seed had ${result.board.levers.length} levers',
        );
      }
    });

    test('generated board has 3 bins', () {
      final result = PuzzleGenerator.generate(42);
      expect(result.board.binOrder.length, 3);
      expect(
        result.board.binOrder.toSet(),
        containsAll([0, 1, 2]),
      );
    });

    test('initialLevers match board levers', () {
      final result = PuzzleGenerator.generate(42);
      expect(
        result.initialLevers.length,
        result.board.levers.length,
      );
    });

    test('all lever positions are within board bounds', () {
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        for (final lever in result.board.levers) {
          expect(
            lever.row,
            inInclusiveRange(0, CascadeBoard.rows - 1),
            reason: 'seed=$seed lever row out of bounds',
          );
          expect(
            lever.col,
            inInclusiveRange(0, CascadeBoard.columns - 1),
            reason: 'seed=$seed lever col out of bounds',
          );
        }
      }
    });

    test('no duplicate lever positions', () {
      for (var seed = 1; seed <= 20; seed++) {
        final result = PuzzleGenerator.generate(seed);
        final positions = result.board.levers
            .map((l) => '${l.row},${l.col}')
            .toSet();
        expect(
          positions.length,
          result.board.levers.length,
          reason: 'seed=$seed has duplicate lever positions',
        );
      }
    });
  });
}
