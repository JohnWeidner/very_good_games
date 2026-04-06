import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/signal/view/view.dart';

/// [GameDefinition] for the Signal grid puzzle game.
class SignalGame extends GameDefinition {
  /// Creates a [SignalGame].
  SignalGame({required super.storageRepository});

  @override
  String get id => 'signal';

  @override
  String get name => 'Signal';

  @override
  String get description => 'Block signals with walls in a daily logic puzzle';

  @override
  IconData get icon => Icons.cell_tower;

  @override
  String get routePath => '/games/signal';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: routePath,
      builder: (context, state) {
        final seed = DailySeed.today();
        return SignalPage(dailySeed: seed);
      },
    ),
  ];
}
