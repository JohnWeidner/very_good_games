import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/view/view.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrPublishRepository extends Mock
    implements NostrPublishRepository {}

class _MockCommunityStatsRepository extends Mock
    implements CommunityStatsRepository {}

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

void main() {
  group('CascadePage', () {
    late GoRouter router;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        // Mark instructions as seen so dialog doesn't block tests.
        'cascade_seen_instructions': true,
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
                  RepositoryProvider<CommunityStatsRepository>(
                    create: (_) => _MockCommunityStatsRepository(),
                  ),
                  RepositoryProvider<NostrProfileRepository>(
                    create: (_) => _MockNostrProfileRepository(),
                  ),
                ],
                child: const CascadePage(dailySeed: 42),
              ),
            ),
          ],
          initialLocation: '/game',
        );
      });
    });

    Future<void> pumpAndWaitForInit(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        // Allow compute() isolate and microtasks to complete.
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('renders AppBar with title', (tester) async {
      await pumpAndWaitForInit(tester);
      expect(find.text('Cascade'), findsOneWidget);
    });

    testWidgets('renders info button in AppBar', (tester) async {
      await pumpAndWaitForInit(tester);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders ball tray', (tester) async {
      await pumpAndWaitForInit(tester);
      expect(find.byType(BallTray), findsOneWidget);
    });

    testWidgets('renders board widget', (tester) async {
      await pumpAndWaitForInit(tester);
      expect(find.byType(CascadeBoardWidget), findsOneWidget);
    });

    testWidgets('renders DROP button in configuring state', (tester) async {
      await pumpAndWaitForInit(tester);
      expect(find.text('DROP'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      // Pump once without settling to catch the loading state.
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      });
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let the cubit finish to avoid pending timers.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
    });
  });
}
