import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/chromix/view/view.dart';

/// [GameDefinition] for the Chromix color-mixing puzzle game.
class ChromixGame extends GameDefinition {
  /// Creates a [ChromixGame].
  ChromixGame({required super.storageRepository});

  @override
  String get id => 'chromix';

  @override
  String get name => 'Chromix';

  @override
  String get description =>
      'Mix colors to match the target in a daily puzzle';

  @override
  IconData get icon => Icons.palette;

  @override
  String get routePath => '/games/chromix';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: routePath,
      builder: (context, state) {
        final seed = DailySeed.today();
        return ChromixPage(dailySeed: seed);
      },
    ),
  ];
}
