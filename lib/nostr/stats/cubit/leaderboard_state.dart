part of 'leaderboard_cubit.dart';

/// Status of leaderboard fetching.
enum LeaderboardStatus {
  /// Not yet fetched.
  initial,

  /// Fetching from relays.
  loading,

  /// Leaderboard loaded successfully.
  loaded,

  /// Leaderboard unavailable (fetch failed or no data).
  unavailable,
}

/// State for [LeaderboardCubit].
class LeaderboardState extends Equatable {
  /// Creates a [LeaderboardState].
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.leaderboard,
    this.hasIdentity = true,
  });

  /// Current loading/result status.
  final LeaderboardStatus status;

  /// The loaded leaderboard, available when [status] is
  /// [LeaderboardStatus.loaded].
  final Leaderboard? leaderboard;

  /// Whether the user has set up a Nostr identity.
  ///
  /// When false, UI should prompt for identity setup instead of showing
  /// leaderboard.
  final bool hasIdentity;

  /// Creates a copy with optional field overrides.
  ///
  /// Uses `Leaderboard? Function()?` wrapper for nullable [leaderboard]
  /// so callers can explicitly set it to null (e.g., when transitioning
  /// back to loading).
  LeaderboardState copyWith({
    LeaderboardStatus? status,
    Leaderboard? Function()? leaderboard,
    bool? hasIdentity,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      leaderboard: leaderboard != null ? leaderboard() : this.leaderboard,
      hasIdentity: hasIdentity ?? this.hasIdentity,
    );
  }

  @override
  List<Object?> get props => [status, leaderboard, hasIdentity];
}
