import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

/// The root widget of Very Good Games.
class App extends StatelessWidget {
  /// Creates the [App] widget.
  const App({
    required GoRouter router,
    required GameRegistry gameRegistry,
    required GameStorageRepository gameStorageRepository,
    required NostrIdentityRepository nostrIdentityRepository,
    required NostrPublishRepository nostrPublishRepository,
    required NostrDeletionRepository nostrDeletionRepository,
    required CommunityStatsRepository communityStatsRepository,
    required ContactListRepository contactListRepository,
    required NostrProfileRepository nostrProfileRepository,
    super.key,
  }) : _router = router,
       _gameRegistry = gameRegistry,
       _gameStorageRepository = gameStorageRepository,
       _nostrIdentityRepository = nostrIdentityRepository,
       _nostrPublishRepository = nostrPublishRepository,
       _nostrDeletionRepository = nostrDeletionRepository,
       _communityStatsRepository = communityStatsRepository,
       _contactListRepository = contactListRepository,
       _nostrProfileRepository = nostrProfileRepository;

  final GoRouter _router;
  final GameRegistry _gameRegistry;
  final GameStorageRepository _gameStorageRepository;
  final NostrIdentityRepository _nostrIdentityRepository;
  final NostrPublishRepository _nostrPublishRepository;
  final NostrDeletionRepository _nostrDeletionRepository;
  final CommunityStatsRepository _communityStatsRepository;
  final ContactListRepository _contactListRepository;
  final NostrProfileRepository _nostrProfileRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _gameRegistry),
        RepositoryProvider.value(value: _gameStorageRepository),
        RepositoryProvider.value(value: _nostrIdentityRepository),
        RepositoryProvider.value(value: _nostrPublishRepository),
        RepositoryProvider.value(value: _nostrDeletionRepository),
        RepositoryProvider.value(value: _communityStatsRepository),
        RepositoryProvider.value(value: _contactListRepository),
        RepositoryProvider.value(value: _nostrProfileRepository),
      ],
      child: MaterialApp.router(
        title: 'Very Good Games',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
