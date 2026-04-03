import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

void main() {
  group('App', () {
    late GoRouter router;
    late GameRegistry gameRegistry;
    late GameStorageRepository storageRepository;
    late NostrIdentityRepository nostrIdentityRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageRepository = GameStorageRepository(preferences: prefs);
      gameRegistry = GameRegistry(games: []);
      router = createRouter(gameRegistry);
      nostrIdentityRepository = _MockNostrIdentityRepository();
    });

    testWidgets('renders MaterialApp.router', (tester) async {
      await tester.pumpWidget(
        App(
          router: router,
          gameRegistry: gameRegistry,
          gameStorageRepository: storageRepository,
          nostrIdentityRepository: nostrIdentityRepository,
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('displays Very Good Games title', (tester) async {
      await tester.pumpWidget(
        App(
          router: router,
          gameRegistry: gameRegistry,
          gameStorageRepository: storageRepository,
          nostrIdentityRepository: nostrIdentityRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Very Good Games'), findsOneWidget);
    });
  });
}
