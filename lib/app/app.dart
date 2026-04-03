import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';

/// The root widget of Very Good Games.
class App extends StatelessWidget {
  /// Creates the [App] widget.
  const App({
    required GoRouter router,
    required GameRegistry gameRegistry,
    required GameStorageRepository gameStorageRepository,
    required NostrIdentityRepository nostrIdentityRepository,
    required NostrPublishRepository nostrPublishRepository,
    super.key,
  }) : _router = router,
       _gameRegistry = gameRegistry,
       _gameStorageRepository = gameStorageRepository,
       _nostrIdentityRepository = nostrIdentityRepository,
       _nostrPublishRepository = nostrPublishRepository;

  final GoRouter _router;
  final GameRegistry _gameRegistry;
  final GameStorageRepository _gameStorageRepository;
  final NostrIdentityRepository _nostrIdentityRepository;
  final NostrPublishRepository _nostrPublishRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _gameRegistry),
        RepositoryProvider.value(value: _gameStorageRepository),
        RepositoryProvider.value(value: _nostrIdentityRepository),
        RepositoryProvider.value(value: _nostrPublishRepository),
      ],
      child: MaterialApp.router(
        title: 'Very Good Games',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
