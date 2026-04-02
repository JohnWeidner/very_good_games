import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

void main() {
  group('QuestionType', () {
    test('has 8 values', () {
      expect(QuestionType.values, hasLength(8));
    });

    test('equals is the only repeatable type', () {
      final repeatables = QuestionType.values
          .where((t) => t.isRepeatable)
          .toList();
      expect(repeatables, hasLength(1));
      expect(repeatables.first, QuestionType.equals);
    });

    test('no-param types have paramCount 0', () {
      final noParam = [
        QuestionType.isOdd,
        QuestionType.isPrime,
        QuestionType.shotgun,
      ];
      for (final type in noParam) {
        expect(type.paramCount, equals(0), reason: type.name);
      }
    });

    test('all param types have paramCount 1', () {
      final oneParam = [
        QuestionType.lessThan,
        QuestionType.isDivisibleBy,
        QuestionType.onesDigitIs,
        QuestionType.equals,
        QuestionType.handGrenade,
      ];
      for (final type in oneParam) {
        expect(type.paramCount, equals(1), reason: type.name);
      }
    });

    test('no two-param types exist', () {
      final twoParam = QuestionType.values.where((t) => t.paramCount == 2);
      expect(twoParam, isEmpty);
    });

    test('all types have non-empty label and description', () {
      for (final type in QuestionType.values) {
        expect(type.label, isNotEmpty, reason: type.name);
        expect(type.description, isNotEmpty, reason: type.name);
      }
    });
  });
}
