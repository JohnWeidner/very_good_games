import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/signal/signal_game.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

void main() {
  group('SignalGame', () {
    late GameStorageRepository storage;
    late SignalGame game;

    setUp(() {
      storage = _MockGameStorageRepository();
      game = SignalGame(storageRepository: storage);
    });

    test('has correct id', () {
      expect(game.id, equals('signal'));
    });

    test('has correct name', () {
      expect(game.name, equals('Signal'));
    });

    test('has correct route path', () {
      expect(game.routePath, equals('/games/signal'));
    });

    test('has one route', () {
      expect(game.routes, hasLength(1));
    });

    test('getDailyStatus returns notStarted when no streak', () async {
      when(() => storage.getStreak('signal')).thenReturn(const StreakData());

      final status = await game.getDailyStatus(DateTime.utc(2026, 4, 3));

      expect(status, equals(DailyGameStatus.notStarted));
    });

    test('getDailyStatus returns completed when completed today', () async {
      when(() => storage.getStreak('signal')).thenReturn(
        StreakData(
          currentStreak: 1,
          bestStreak: 1,
          lastCompletedDate: DateTime.utc(2026, 4, 3),
        ),
      );

      final status = await game.getDailyStatus(DateTime.utc(2026, 4, 3));

      expect(status, equals(DailyGameStatus.completed));
    });

    test('getDailyStatus returns notStarted for different day', () async {
      when(() => storage.getStreak('signal')).thenReturn(
        StreakData(
          currentStreak: 1,
          bestStreak: 1,
          lastCompletedDate: DateTime.utc(2026, 4, 2),
        ),
      );

      final status = await game.getDailyStatus(DateTime.utc(2026, 4, 3));

      expect(status, equals(DailyGameStatus.notStarted));
    });
  });
}
