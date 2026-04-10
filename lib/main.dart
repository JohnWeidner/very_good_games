import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/app_bloc_observer.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/cascade_game.dart';
import 'package:very_good_games/games/chromix/chromix_game.dart';
import 'package:very_good_games/games/guess_the_number/guess_the_number_game.dart';
import 'package:very_good_games/games/signal/signal_game.dart';
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
      CascadeGame(storageRepository: storageRepository),
      ChromixGame(storageRepository: storageRepository),
      GuessTheNumberGame(storageRepository: storageRepository),
      SignalGame(storageRepository: storageRepository),
    ],
  );
  final router = createRouter(gameRegistry);

  const secureStorage = FlutterSecureStorage();
  final nostrIdentityRepository = NostrIdentityRepository(
    secureStorage: secureStorage,
  );
  final ndkProvider = NdkProvider.lazy();
  final nostrPublishRepository = NostrPublishRepository(
    ndkProvider: ndkProvider,
  );
  final nostrDeletionRepository = NostrDeletionRepository(
    ndkProvider: ndkProvider,
  );
  final communityStatsRepository = CommunityStatsRepository(
    ndkProvider: ndkProvider,
  );
  final contactListRepository = ContactListRepository(ndkProvider: ndkProvider);

  // Initialize Drift database for profile caching.
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDir.path, 'nostr_identity.db');
  final nostrDatabase = NostrDatabase(
    NativeDatabase.createInBackground(File(dbPath)),
  );
  final nostrProfileRepository = NostrProfileRepository(
    ndkProvider: ndkProvider,
    database: nostrDatabase,
  );

  runApp(
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
}
