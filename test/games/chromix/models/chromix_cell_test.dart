import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('ChromixCell', () {
    group('EmptyCell', () {
      test('ChromixCell.empty is an EmptyCell', () {
        expect(ChromixCell.empty, isA<EmptyCell>());
      });

      test('equality', () {
        expect(ChromixCell.empty, equals(ChromixCell.empty));
        expect(ChromixCell.empty, equals(const EmptyCell()));
      });

      test('toString', () {
        expect(
          ChromixCell.empty.toString(),
          equals('ChromixCell.empty'),
        );
      });
    });

    group('BlockerCell', () {
      test('ChromixCell.blocker is a BlockerCell', () {
        expect(ChromixCell.blocker, isA<BlockerCell>());
      });

      test('equality', () {
        expect(ChromixCell.blocker, equals(ChromixCell.blocker));
        expect(ChromixCell.blocker, equals(const BlockerCell()));
      });

      test('toString', () {
        expect(
          ChromixCell.blocker.toString(),
          equals('ChromixCell.blocker'),
        );
      });
    });

    group('ColorCell', () {
      test('ChromixCell.color creates a ColorCell', () {
        final cell = ChromixCell.color(ChromixColor.red);
        expect(cell, isA<ColorCell>());
        expect(cell.color, equals(ChromixColor.red));
        expect(cell.isPreFilled, isFalse);
      });

      test('isPreFilled defaults to false', () {
        const cell = ColorCell(ChromixColor.blue);
        expect(cell.isPreFilled, isFalse);
      });

      test('isPreFilled can be set to true', () {
        const cell = ColorCell(ChromixColor.blue, isPreFilled: true);
        expect(cell.isPreFilled, isTrue);
      });

      test('isLocked is true for secondary colors', () {
        const orange = ColorCell(ChromixColor.orange);
        const green = ColorCell(ChromixColor.green);
        const purple = ColorCell(ChromixColor.purple);
        expect(orange.isLocked, isTrue);
        expect(green.isLocked, isTrue);
        expect(purple.isLocked, isTrue);
      });

      test('isLocked is false for primary colors', () {
        const red = ColorCell(ChromixColor.red);
        const yellow = ColorCell(ChromixColor.yellow);
        const blue = ColorCell(ChromixColor.blue);
        expect(red.isLocked, isFalse);
        expect(yellow.isLocked, isFalse);
        expect(blue.isLocked, isFalse);
      });

      test('equality considers color and isPreFilled', () {
        const a = ColorCell(ChromixColor.red);
        const b = ColorCell(ChromixColor.red);
        const c = ColorCell(ChromixColor.red, isPreFilled: true);
        const d = ColorCell(ChromixColor.blue);

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
        expect(a, isNot(equals(d)));
      });

      test('toString', () {
        const cell = ColorCell(ChromixColor.red);
        expect(
          cell.toString(),
          equals(
            'ChromixCell.color(ChromixColor.red, isPreFilled: false)',
          ),
        );
      });
    });

    group('different cell types are not equal', () {
      test('empty != blocker', () {
        expect(ChromixCell.empty, isNot(equals(ChromixCell.blocker)));
      });

      test('empty != color', () {
        expect(
          ChromixCell.empty,
          isNot(equals(const ColorCell(ChromixColor.red))),
        );
      });

      test('blocker != color', () {
        expect(
          ChromixCell.blocker,
          isNot(equals(const ColorCell(ChromixColor.red))),
        );
      });
    });

    group('serialization', () {
      test('EmptyCell round-trip', () {
        const cell = EmptyCell();
        final json = cell.toJson();
        expect(json, equals({'type': 'empty'}));
        expect(ChromixCell.fromJson(json), equals(cell));
      });

      test('BlockerCell round-trip', () {
        const cell = BlockerCell();
        final json = cell.toJson();
        expect(json, equals({'type': 'blocker'}));
        expect(ChromixCell.fromJson(json), equals(cell));
      });

      test('ColorCell round-trip', () {
        const cell = ColorCell(ChromixColor.orange, isPreFilled: true);
        final json = cell.toJson();
        expect(
          json,
          equals({
            'type': 'color',
            'color': 'orange',
            'isPreFilled': true,
          }),
        );
        expect(ChromixCell.fromJson(json), equals(cell));
      });

      test('ColorCell round-trip with isPreFilled false', () {
        const cell = ColorCell(ChromixColor.blue);
        final json = cell.toJson();
        expect(ChromixCell.fromJson(json), equals(cell));
      });

      test('fromJson throws for unknown type', () {
        expect(
          () => ChromixCell.fromJson({'type': 'unknown'}),
          throwsArgumentError,
        );
      });
    });
  });
}
