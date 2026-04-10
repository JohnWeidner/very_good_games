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
    this.followedPubkeys = const {},
    this.followsStatus = LeaderboardStatus.initial,
  });

  /// Current loading/result status for the global leaderboard.
  final LeaderboardStatus status;

  /// The loaded leaderboard, available when [status] is
  /// [LeaderboardStatus.loaded].
  final Leaderboard? leaderboard;

  /// Whether the user has set up a Nostr identity.
  ///
  /// When false, UI shows identity prompt above leaderboard (not as a gate).
  final bool hasIdentity;

  /// Hex pubkeys the current user follows (from kind-3).
  final Set<String> followedPubkeys;

  /// Loading status for follows-aware merge, independent of [status].
  final LeaderboardStatus followsStatus;

  /// Creates a copy with optional field overrides.
  ///
  /// Uses `Leaderboard? Function()?` wrapper for nullable [leaderboard]
  /// so callers can explicitly set it to null (e.g., when transitioning
  /// back to loading).
  LeaderboardState copyWith({
    LeaderboardStatus? status,
    Leaderboard? Function()? leaderboard,
    bool? hasIdentity,
    Set<String>? followedPubkeys,
    LeaderboardStatus? followsStatus,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      leaderboard: leaderboard != null ? leaderboard() : this.leaderboard,
      hasIdentity: hasIdentity ?? this.hasIdentity,
      followedPubkeys: followedPubkeys ?? this.followedPubkeys,
      followsStatus: followsStatus ?? this.followsStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    leaderboard,
    hasIdentity,
    followedPubkeys,
    followsStatus,
  ];
}
