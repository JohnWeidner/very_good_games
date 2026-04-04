import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/models/models.dart';

void main() {
  group('Cell', () {
    test('Cell.empty is an EmptyCell', () {
      expect(Cell.empty, isA<EmptyCell>());
    });

    test('Cell.wall is a WallCell', () {
      expect(Cell.wall, isA<WallCell>());
    });

    test('Cell.tower creates a Tower with targetCount', () {
      final tower = Cell.tower(5);
      expect(tower, isA<Tower>());
      expect(tower.targetCount, equals(5));
    });

    test('EmptyCell equality', () {
      expect(Cell.empty, equals(Cell.empty));
      expect(Cell.empty, equals(const EmptyCell()));
    });

    test('WallCell equality', () {
      expect(Cell.wall, equals(Cell.wall));
      expect(Cell.wall, equals(const WallCell()));
    });

    test('Tower equality by targetCount', () {
      expect(Cell.tower(3), equals(Cell.tower(3)));
      expect(Cell.tower(3), isNot(equals(Cell.tower(5))));
    });

    test('different cell types are not equal', () {
      expect(Cell.empty, isNot(equals(Cell.wall)));
      expect(Cell.empty, isNot(equals(Cell.tower(0))));
      expect(Cell.wall, isNot(equals(Cell.tower(0))));
    });

    test('toString representations', () {
      expect(Cell.empty.toString(), equals('Cell.empty'));
      expect(Cell.wall.toString(), equals('Cell.wall'));
      expect(Cell.tower(7).toString(), equals('Cell.tower(7)'));
    });
  });
}
