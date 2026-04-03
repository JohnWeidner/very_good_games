part of 'community_stats_cubit.dart';

/// The status of community stats loading.
enum CommunityStatsStatus {
  /// Not yet fetched.
  initial,

  /// Fetching from relays.
  loading,

  /// Stats loaded successfully.
  loaded,

  /// Stats unavailable (fetch failed or no data).
  unavailable,
}

/// State for [CommunityStatsCubit].
class CommunityStatsState extends Equatable {
  /// Creates a [CommunityStatsState].
  const CommunityStatsState({
    this.status = CommunityStatsStatus.initial,
    this.stats,
  });

  /// The current loading status.
  final CommunityStatsStatus status;

  /// The loaded stats, available when [status] is
  /// [CommunityStatsStatus.loaded].
  final CommunityStats? stats;

  /// Creates a copy with the given fields replaced.
  CommunityStatsState copyWith({
    CommunityStatsStatus? status,
    CommunityStats? stats,
  }) {
    return CommunityStatsState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [status, stats];
}
