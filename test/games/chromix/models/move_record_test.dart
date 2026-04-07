import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('MoveRecord', () {
    test('stores cellIndex and previousCell', () {
      const record = MoveRecord(
        cellIndex: 5,
        previousCell: EmptyCell(),
      );
      expect(record.cellIndex, equals(5));
      expect(record.previousCell, equals(const EmptyCell()));
    });

    test('equality', () {
      const a = MoveRecord(cellIndex: 3, previousCell: EmptyCell());
      const b = MoveRecord(cellIndex: 3, previousCell: EmptyCell());
      const c = MoveRecord(cellIndex: 4, previousCell: EmptyCell());
      const d = MoveRecord(
        cellIndex: 3,
        previousCell: ColorCell(ChromixColor.red),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    group('serialization', () {
      test('round-trip with EmptyCell', () {
        const record = MoveRecord(
          cellIndex: 7,
          previousCell: EmptyCell(),
        );
        final json = record.toJson();
        expect(
          json,
          equals({
            'cellIndex': 7,
            'previousCell': {'type': 'empty'},
          }),
        );
        expect(MoveRecord.fromJson(json), equals(record));
      });

      test('round-trip with ColorCell', () {
        const record = MoveRecord(
          cellIndex: 2,
          previousCell: ColorCell(
            ChromixColor.purple,
            isPreFilled: true,
          ),
        );
        final json = record.toJson();
        expect(MoveRecord.fromJson(json), equals(record));
      });

      test('round-trip with BlockerCell', () {
        const record = MoveRecord(
          cellIndex: 0,
          previousCell: BlockerCell(),
        );
        final json = record.toJson();
        expect(MoveRecord.fromJson(json), equals(record));
      });
    });
  });
}
