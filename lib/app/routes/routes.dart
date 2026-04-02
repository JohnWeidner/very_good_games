import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/view/home_page.dart';
import 'package:very_good_games/settings/settings.dart';

/// Creates the app's [GoRouter] with routes from the [gameRegistry].
GoRouter createRouter(GameRegistry gameRegistry) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      // Game routes injected from the registry.
      ...gameRegistry.games.expand((game) => game.routes),
    ],
  );
}
