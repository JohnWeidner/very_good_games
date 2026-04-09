import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/view/view.dart';

/// [GameDefinition] for the Cascade ball-routing puzzle game.
class CascadeGame extends GameDefinition {
  /// Creates a [CascadeGame].
  CascadeGame({required super.storageRepository});

  @override
  String get id => 'cascade';

  @override
  String get name => 'Cascade';

  @override
  String get description =>
      'Route balls through levers in a daily puzzle';

  @override
  IconData get icon => Icons.arrow_downward;

  @override
  String get routePath => '/games/cascade';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: routePath,
      builder: (context, state) {
        final seed = DailySeed.today();
        return CascadePage(dailySeed: seed);
      },
    ),
  ];
}
