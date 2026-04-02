import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/core/daily_seed/daily_seed.dart';

void main() {
  group('DailySeed', () {
    test('forDate returns same value for same date', () {
      final date = DateTime.utc(2026, 4, 2);
      final seed1 = DailySeed.forDate(date);
      final seed2 = DailySeed.forDate(date);

      expect(seed1, equals(seed2));
    });

    test('forDate returns different values for different dates', () {
      final seed1 = DailySeed.forDate(DateTime.utc(2026, 4, 2));
      final seed2 = DailySeed.forDate(DateTime.utc(2026, 4, 3));

      expect(seed1, isNot(equals(seed2)));
    });

    test('forDate ignores time components', () {
      final morning = DateTime.utc(2026, 4, 2, 8, 30);
      final evening = DateTime.utc(2026, 4, 2, 22, 15);

      expect(DailySeed.forDate(morning), equals(DailySeed.forDate(evening)));
    });

    test('forDate converts local time to UTC', () {
      final localDate = DateTime(2026, 4, 2, 12);
      final utcDate = DateTime.utc(2026, 4, 2, 12);

      expect(DailySeed.forDate(localDate), equals(DailySeed.forDate(utcDate)));
    });

    test('forDate returns a positive integer', () {
      final seed = DailySeed.forDate(DateTime.utc(2026));

      expect(seed, isPositive);
    });

    test('today returns a positive integer', () {
      expect(DailySeed.today(), isPositive);
    });

    test('forDate produces known deterministic value', () {
      // Pin a specific date to a hardcoded hash to detect regressions.
      // If this test fails, the seed algorithm changed — which would break
      // existing streak data.
      final seed = DailySeed.forDate(DateTime.utc(2026));

      expect(seed, equals(134668363));
    });
  });
}
