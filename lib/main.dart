import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/app_bloc_observer.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/guess_the_number_game.dart';
import 'package:very_good_games/games/signal/signal_game.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();

  final preferences = await SharedPreferences.getInstance();
  final storageRepository = GameStorageRepository(preferences: preferences);

  // Register games here as they are built.
  final gameRegistry = GameRegistry(
    games: [
      GuessTheNumberGame(storageRepository: storageRepository),
      SignalGame(storageRepository: storageRepository),
    ],
  );
  final router = createRouter(gameRegistry);

  const secureStorage = FlutterSecureStorage();
  final nostrIdentityRepository = NostrIdentityRepository(
    secureStorage: secureStorage,
  );
  final nostrPublishRepository = NostrPublishRepository.lazy();
  final nostrDeletionRepository = NostrDeletionRepository.lazy();
  final communityStatsRepository = CommunityStatsRepository.lazy();

  runApp(
    App(
      router: router,
      gameRegistry: gameRegistry,
      gameStorageRepository: storageRepository,
      nostrIdentityRepository: nostrIdentityRepository,
      nostrPublishRepository: nostrPublishRepository,
      nostrDeletionRepository: nostrDeletionRepository,
      communityStatsRepository: communityStatsRepository,
    ),
  );
}
