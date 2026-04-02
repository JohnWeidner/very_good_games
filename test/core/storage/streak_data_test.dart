import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/core/storage/streak_data.dart';

void main() {
  group('StreakData', () {
    test('defaults to zero streaks and no last completed date', () {
      const data = StreakData();

      expect(data.currentStreak, equals(0));
      expect(data.bestStreak, equals(0));
      expect(data.lastCompletedDate, isNull);
    });

    test('supports value equality', () {
      final date = DateTime.utc(2026, 4, 2);
      final a = StreakData(
        currentStreak: 3,
        bestStreak: 5,
        lastCompletedDate: date,
      );
      final b = StreakData(
        currentStreak: 3,
        bestStreak: 5,
        lastCompletedDate: date,
      );

      expect(a, equals(b));
    });

    group('recordCompletion', () {
      test('starts a new streak from zero', () {
        const data = StreakData();
        final result = data.recordCompletion(DateTime.utc(2026, 4, 2));

        expect(result.currentStreak, equals(1));
        expect(result.bestStreak, equals(1));
        expect(result.lastCompletedDate, equals(DateTime.utc(2026, 4, 2)));
      });

      test('increments streak on consecutive day', () {
        final data = StreakData(
          currentStreak: 3,
          bestStreak: 5,
          lastCompletedDate: DateTime.utc(2026, 4),
        );
        final result = data.recordCompletion(DateTime.utc(2026, 4, 2));

        expect(result.currentStreak, equals(4));
        expect(result.bestStreak, equals(5));
      });

      test('resets streak after a gap', () {
        final data = StreakData(
          currentStreak: 3,
          bestStreak: 5,
          lastCompletedDate: DateTime.utc(2026, 3, 30),
        );
        final result = data.recordCompletion(DateTime.utc(2026, 4, 2));

        expect(result.currentStreak, equals(1));
        expect(result.bestStreak, equals(5));
      });

      test('updates best streak when current exceeds it', () {
        final data = StreakData(
          currentStreak: 5,
          bestStreak: 5,
          lastCompletedDate: DateTime.utc(2026, 4),
        );
        final result = data.recordCompletion(DateTime.utc(2026, 4, 2));

        expect(result.currentStreak, equals(6));
        expect(result.bestStreak, equals(6));
      });

      test('returns same data when already completed today', () {
        final data = StreakData(
          currentStreak: 3,
          bestStreak: 5,
          lastCompletedDate: DateTime.utc(2026, 4, 2),
        );
        final result = data.recordCompletion(DateTime.utc(2026, 4, 2));

        expect(result, equals(data));
      });
    });
  });
}
