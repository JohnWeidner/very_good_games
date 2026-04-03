import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/view/view.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrPublishRepository extends Mock
    implements NostrPublishRepository {}

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
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Home'))),
            ),
            GoRoute(
              path: '/game',
              builder: (context, state) => MultiRepositoryProvider(
                providers: [
                  RepositoryProvider<GameStorageRepository>.value(
                    value: storageRepo,
                  ),
                  RepositoryProvider<NostrIdentityRepository>(
                    create: (_) => _MockNostrIdentityRepository(),
                  ),
                  RepositoryProvider<NostrPublishRepository>(
                    create: (_) => _MockNostrPublishRepository(),
                  ),
                ],
                child: const GamePage(targetNumber: 42, dailySeed: 12345),
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
