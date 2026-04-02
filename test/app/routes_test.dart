import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';

class _MockGameDefinition extends Mock implements GameDefinition {}

void main() {
  group('createRouter', () {
    test('creates router with home route', () {
      final registry = GameRegistry(games: []);
      final router = createRouter(registry);

      expect(router, isA<GoRouter>());
    });

    test('includes settings route', () {
      final registry = GameRegistry(games: []);
      final router = createRouter(registry);

      final match = router.configuration.findMatch(Uri.parse('/settings'));
      expect(match.matches, isNotEmpty);
    });

    test('includes game routes from registry', () {
      final game = _MockGameDefinition();
      when(() => game.routes).thenReturn([
        GoRoute(path: '/games/test', builder: (_, __) => const SizedBox()),
      ]);

      final registry = GameRegistry(games: [game]);
      final router = createRouter(registry);

      expect(router, isA<GoRouter>());
    });
  });
}
