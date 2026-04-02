part of 'home_cubit.dart';

/// The loading status of the home screen.
enum HomeStatus {
  /// Initial state before any load.
  initial,

  /// Games are being loaded.
  loading,

  /// Games loaded successfully.
  loaded,

  /// An error occurred while loading.
  error,
}

/// A single game entry for the home screen, combining definition + status.
class HomeGameEntry extends Equatable {
  /// Creates a [HomeGameEntry].
  const HomeGameEntry({
    required this.definition,
    required this.dailyStatus,
    required this.streak,
  });

  /// The game's definition (metadata, routes).
  final GameDefinition definition;

  /// The game's status for today.
  final DailyGameStatus dailyStatus;

  /// The player's streak data for this game.
  final StreakData streak;

  @override
  List<Object?> get props => [definition.id, dailyStatus, streak];
}

/// The state of the home screen.
class HomeState extends Equatable {
  /// Creates a [HomeState].
  const HomeState({this.status = HomeStatus.initial, this.games = const []});

  /// The current loading status.
  final HomeStatus status;

  /// The list of games with their daily statuses.
  final List<HomeGameEntry> games;

  /// Creates a copy of this state with the given fields replaced.
  HomeState copyWith({HomeStatus? status, List<HomeGameEntry>? games}) {
    return HomeState(status: status ?? this.status, games: games ?? this.games);
  }

  @override
  List<Object> get props => [status, games];
}
