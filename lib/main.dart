import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/app_bloc_observer.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();

  final preferences = await SharedPreferences.getInstance();
  final storageRepository = GameStorageRepository(preferences: preferences);

  // Register games here as they are built.
  final gameRegistry = GameRegistry(games: []);
  final router = createRouter(gameRegistry);

  runApp(
    App(
      router: router,
      gameRegistry: gameRegistry,
      gameStorageRepository: storageRepository,
    ),
  );
}
