import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/storage/storage.dart';

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
  /// Creates a [GameDefinition] with access to [storageRepository].
  GameDefinition({required GameStorageRepository storageRepository})
    : _storageRepository = storageRepository;

  final GameStorageRepository _storageRepository;

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
  ///
  /// Checks whether the game was completed today by comparing the
  /// streak's last completed date with the given [date].
  Future<DailyGameStatus> getDailyStatus(DateTime date) async {
    final streak = _storageRepository.getStreak(id);
    if (streak.lastCompletedDate == null) {
      return DailyGameStatus.notStarted;
    }

    final lastUtc = streak.lastCompletedDate!.toUtc();
    final dateUtc = date.toUtc();

    if (lastUtc.year == dateUtc.year &&
        lastUtc.month == dateUtc.month &&
        lastUtc.day == dateUtc.day) {
      return DailyGameStatus.completed;
    }

    return DailyGameStatus.notStarted;
  }
}
