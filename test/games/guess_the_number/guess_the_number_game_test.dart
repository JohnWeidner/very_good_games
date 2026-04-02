import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/guess_the_number_game.dart';

void main() {
  group('GuessTheNumberGame', () {
    late GameStorageRepository storageRepository;
    late GuessTheNumberGame game;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance().then((prefs) {
        storageRepository = GameStorageRepository(preferences: prefs);
        game = GuessTheNumberGame(storageRepository: storageRepository);
      });
    });

    test('has correct id', () {
      expect(game.id, equals('guess_the_number'));
    });

    test('has correct name', () {
      expect(game.name, equals('Guess the Number'));
    });

    test('has correct routePath', () {
      expect(game.routePath, equals('/games/guess-the-number'));
    });

    test('routes is not empty', () {
      expect(game.routes, isNotEmpty);
    });

    test('getDailyStatus returns notStarted when no data', () async {
      final status = await game.getDailyStatus(DateTime.utc(2026));
      expect(status, equals(DailyGameStatus.notStarted));
    });

    test('getDailyStatus returns completed when streak matches date', () async {
      final today = DateTime.utc(2026, 4, 2);
      await storageRepository.saveStreak(
        'guess_the_number',
        StreakData(currentStreak: 1, bestStreak: 1, lastCompletedDate: today),
      );

      final status = await game.getDailyStatus(today);
      expect(status, equals(DailyGameStatus.completed));
    });

    test('getDailyStatus returns notStarted for a different day', () async {
      final yesterday = DateTime.utc(2026, 3, 31);
      final today = DateTime.utc(2026, 4, 2);
      await storageRepository.saveStreak(
        'guess_the_number',
        StreakData(
          currentStreak: 1,
          bestStreak: 1,
          lastCompletedDate: yesterday,
        ),
      );

      final status = await game.getDailyStatus(today);
      expect(status, equals(DailyGameStatus.notStarted));
    });
  });
}
