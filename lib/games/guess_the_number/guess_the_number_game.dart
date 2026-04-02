import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/guess_the_number/view/view.dart';

/// [GameDefinition] for the Guess the Number game.
class GuessTheNumberGame extends GameDefinition {
  /// Creates a [GuessTheNumberGame].
  GuessTheNumberGame({required GameStorageRepository storageRepository})
    : _storageRepository = storageRepository;

  final GameStorageRepository _storageRepository;

  @override
  String get id => 'guess_the_number';

  @override
  String get name => 'Guess the Number';

  @override
  String get description =>
      'Narrow down 1-400 using strategic questions';

  @override
  IconData get icon => Icons.grid_on;

  @override
  String get routePath => '/games/guess-the-number';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: routePath,
      builder: (context, state) {
        final seed = DailySeed.today();
        final target = (seed % 400) + 1;
        return GamePage(targetNumber: target, dailySeed: seed);
      },
    ),
  ];

  @override
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
