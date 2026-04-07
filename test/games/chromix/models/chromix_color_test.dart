import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('ChromixColor', () {
    test('has 6 values', () {
      expect(ChromixColor.values, hasLength(6));
    });

    group('isPrimary', () {
      test('returns true for red, yellow, blue', () {
        expect(ChromixColor.red.isPrimary, isTrue);
        expect(ChromixColor.yellow.isPrimary, isTrue);
        expect(ChromixColor.blue.isPrimary, isTrue);
      });

      test('returns false for secondaries', () {
        expect(ChromixColor.orange.isPrimary, isFalse);
        expect(ChromixColor.green.isPrimary, isFalse);
        expect(ChromixColor.purple.isPrimary, isFalse);
      });
    });

    group('isSecondary', () {
      test('returns true for orange, green, purple', () {
        expect(ChromixColor.orange.isSecondary, isTrue);
        expect(ChromixColor.green.isSecondary, isTrue);
        expect(ChromixColor.purple.isSecondary, isTrue);
      });

      test('returns false for primaries', () {
        expect(ChromixColor.red.isSecondary, isFalse);
        expect(ChromixColor.yellow.isSecondary, isFalse);
        expect(ChromixColor.blue.isSecondary, isFalse);
      });
    });
  });
}
