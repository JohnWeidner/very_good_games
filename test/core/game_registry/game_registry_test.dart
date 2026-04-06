import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

class _TestGameDefinition extends GameDefinition {
  _TestGameDefinition() : super(storageRepository: _mockStorage());

  static GameStorageRepository _mockStorage() {
    final mock = _MockGameStorageRepository();
    when(() => mock.getStreak(any())).thenReturn(const StreakData());
    return mock;
  }

  @override
  String get id => 'test_game';

  @override
  String get name => 'Test Game';

  @override
  String get description => 'A test game';

  @override
  IconData get icon => const IconData(0);

  @override
  String get routePath => '/games/test';

  @override
  List<RouteBase> get routes => [
    GoRoute(path: routePath, builder: (_, __) => const SizedBox()),
  ];
}

void main() {
  group('GameRegistry', () {
    test('holds list of registered games', () {
      final game = _TestGameDefinition();
      final registry = GameRegistry(games: [game]);

      expect(registry.games, hasLength(1));
      expect(registry.games.first, equals(game));
    });

    test('supports empty game list', () {
      final registry = GameRegistry(games: []);

      expect(registry.games, isEmpty);
    });
  });

  group('GameDefinition', () {
    late GameDefinition game;

    setUp(() {
      game = _TestGameDefinition();
    });

    test('exposes all required properties', () {
      expect(game.id, equals('test_game'));
      expect(game.name, equals('Test Game'));
      expect(game.description, equals('A test game'));
      expect(game.icon, isA<IconData>());
      expect(game.routePath, equals('/games/test'));
      expect(game.routes, hasLength(1));
    });

    test('getDailyStatus returns a status', () async {
      final status = await game.getDailyStatus(DateTime.utc(2026));

      expect(status, equals(DailyGameStatus.notStarted));
    });
  });

  group('DailyGameStatus', () {
    test('has expected values', () {
      expect(DailyGameStatus.values, hasLength(2));
      expect(DailyGameStatus.values, contains(DailyGameStatus.notStarted));
      expect(DailyGameStatus.values, contains(DailyGameStatus.completed));
    });
  });
}
