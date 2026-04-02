import 'package:very_good_games/core/game_registry/game_definition.dart';

export 'game_definition.dart';

/// Holds the list of all registered games in the hub.
class GameRegistry {
  /// Creates a [GameRegistry] with the given list of [games].
  GameRegistry({required List<GameDefinition> games})
    : games = List.unmodifiable(games);

  /// All registered games (unmodifiable).
  final List<GameDefinition> games;
}
