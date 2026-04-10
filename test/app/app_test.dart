import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrPublishRepository extends Mock
    implements NostrPublishRepository {}

class _MockNostrDeletionRepository extends Mock
    implements NostrDeletionRepository {}

class _MockCommunityStatsRepository extends Mock
    implements CommunityStatsRepository {}

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

class _MockContactListRepository extends Mock
    implements ContactListRepository {}

void main() {
  group('App', () {
    late GoRouter router;
    late GameRegistry gameRegistry;
    late GameStorageRepository storageRepository;
    late NostrIdentityRepository nostrIdentityRepository;
    late NostrPublishRepository nostrPublishRepository;
    late NostrDeletionRepository nostrDeletionRepository;
    late CommunityStatsRepository communityStatsRepository;
    late ContactListRepository contactListRepository;
    late NostrProfileRepository nostrProfileRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageRepository = GameStorageRepository(preferences: prefs);
      gameRegistry = GameRegistry(games: []);
      router = createRouter(gameRegistry);
      nostrIdentityRepository = _MockNostrIdentityRepository();
      nostrPublishRepository = _MockNostrPublishRepository();
      nostrDeletionRepository = _MockNostrDeletionRepository();
      communityStatsRepository = _MockCommunityStatsRepository();
      contactListRepository = _MockContactListRepository();
      nostrProfileRepository = _MockNostrProfileRepository();
    });

    testWidgets('renders MaterialApp.router', (tester) async {
      await tester.pumpWidget(
        App(
          router: router,
          gameRegistry: gameRegistry,
          gameStorageRepository: storageRepository,
          nostrIdentityRepository: nostrIdentityRepository,
          nostrPublishRepository: nostrPublishRepository,
          nostrDeletionRepository: nostrDeletionRepository,
          communityStatsRepository: communityStatsRepository,
          contactListRepository: contactListRepository,
          nostrProfileRepository: nostrProfileRepository,
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
          nostrPublishRepository: nostrPublishRepository,
          nostrDeletionRepository: nostrDeletionRepository,
          communityStatsRepository: communityStatsRepository,
          contactListRepository: contactListRepository,
          nostrProfileRepository: nostrProfileRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Very Good Games'), findsOneWidget);
    });
  });
}
