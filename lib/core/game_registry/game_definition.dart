import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The daily status of a game.
enum DailyGameStatus {
  /// The game has not been started today.
  notStarted,

  /// The game has been completed today.
  completed,
}

/// Contract that every game module must implement to register
/// with the hub shell.
abstract class GameDefinition {
  /// Unique identifier for this game (e.g., 'guess_the_number').
  String get id;

  /// Display name shown on the home screen tile.
  String get name;

  /// Short description shown below the game name.
  String get description;

  /// Icon displayed on the game tile.
  IconData get icon;

  /// The route path for this game (e.g., '/games/guess-the-number').
  String get routePath;

  /// Returns the GoRoute(s) for this game module.
  /// The shell adds these to the router automatically.
  List<RouteBase> get routes;

  /// Returns the current daily status for this game.
  /// The shell calls this to render the tile state.
  Future<DailyGameStatus> getDailyStatus(DateTime date);
}
