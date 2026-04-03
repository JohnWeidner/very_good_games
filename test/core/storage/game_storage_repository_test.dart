import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/storage/storage.dart';

void main() {
  group('GameStorageRepository', () {
    late SharedPreferences preferences;
    late GameStorageRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = GameStorageRepository(preferences: preferences);
    });

    group('getStreak', () {
      test('returns default StreakData when no data stored', () {
        final streak = repository.getStreak('test_game');

        expect(streak, equals(const StreakData()));
      });

      test('returns stored streak data', () async {
        await preferences.setInt('test_game_current_streak', 3);
        await preferences.setInt('test_game_best_streak', 7);
        await preferences.setInt(
          'test_game_last_completed',
          DateTime.utc(2026, 4, 2).millisecondsSinceEpoch,
        );

        final streak = repository.getStreak('test_game');

        expect(streak.currentStreak, equals(3));
        expect(streak.bestStreak, equals(7));
        expect(streak.lastCompletedDate, equals(DateTime.utc(2026, 4, 2)));
      });
    });

    group('saveStreak', () {
      test('persists streak data', () async {
        final data = StreakData(
          currentStreak: 5,
          bestStreak: 10,
          lastCompletedDate: DateTime.utc(2026, 4, 2),
        );

        await repository.saveStreak('test_game', data);

        expect(preferences.getInt('test_game_current_streak'), equals(5));
        expect(preferences.getInt('test_game_best_streak'), equals(10));
        expect(
          preferences.getInt('test_game_last_completed'),
          equals(DateTime.utc(2026, 4, 2).millisecondsSinceEpoch),
        );
      });

      test('persists streak data without last completed date', () async {
        const data = StreakData();

        await repository.saveStreak('test_game', data);

        expect(preferences.getInt('test_game_current_streak'), equals(0));
        expect(preferences.getInt('test_game_best_streak'), equals(0));
        expect(preferences.getInt('test_game_last_completed'), isNull);
      });
    });

    group('saveSession / getSession', () {
      test('returns null when no session stored', () {
        expect(repository.getSession('test_game'), isNull);
      });

      test('round-trips session data', () async {
        final session = {
          'dailySeed': 42,
          'cells': [0, 1, 0, 2],
          'usedQuestionTypes': [0, 1],
          'questionCount': 3,
          'elapsedSeconds': 45,
          'timerStarted': true,
        };

        await repository.saveSession('test_game', session);

        final loaded = repository.getSession('test_game');
        expect(loaded, isNotNull);
        expect(loaded!['dailySeed'], equals(42));
        expect(loaded['cells'], equals([0, 1, 0, 2]));
        expect(loaded['usedQuestionTypes'], equals([0, 1]));
        expect(loaded['questionCount'], equals(3));
        expect(loaded['elapsedSeconds'], equals(45));
        expect(loaded['timerStarted'], isTrue);
      });

      test('clears session when saving null', () async {
        await repository.saveSession('test_game', {'dailySeed': 1});
        await repository.saveSession('test_game', null);

        expect(repository.getSession('test_game'), isNull);
      });
    });

    test('isolates data between games', () async {
      final data1 = StreakData(
        currentStreak: 3,
        bestStreak: 3,
        lastCompletedDate: DateTime.utc(2026, 4, 2),
      );
      final data2 = StreakData(
        currentStreak: 7,
        bestStreak: 12,
        lastCompletedDate: DateTime.utc(2026, 4),
      );

      await repository.saveStreak('game_a', data1);
      await repository.saveStreak('game_b', data2);

      expect(repository.getStreak('game_a'), equals(data1));
      expect(repository.getStreak('game_b'), equals(data2));
    });
  });
}
