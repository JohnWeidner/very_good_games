import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/view/view.dart';

void main() {
  group('GamePage', () {
    late GoRouter router;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        // Mark instructions as seen so dialog doesn't block tests.
        'guess_the_number_seen_instructions': true,
      });
      return SharedPreferences.getInstance().then((prefs) {
        final storageRepo = GameStorageRepository(preferences: prefs);
        router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Home')),
              ),
            ),
            GoRoute(
              path: '/game',
              builder: (context, state) =>
                  RepositoryProvider<GameStorageRepository>.value(
                value: storageRepo,
                child: const GamePage(
                  targetNumber: 42,
                  dailySeed: 12345,
                ),
              ),
            ),
          ],
          initialLocation: '/game',
        );
      });
    });

    testWidgets('renders AppBar with title', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Guess the Number'), findsOneWidget);
    });

    testWidgets('renders info button in AppBar', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders card tray', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(CardTray), findsOneWidget);
    });

    testWidgets('renders score bar', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreBar), findsOneWidget);
    });

    testWidgets('renders game header', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(GameHeader), findsOneWidget);
    });

    testWidgets('renders number grid', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(NumberGrid), findsOneWidget);
    });
  });
}
