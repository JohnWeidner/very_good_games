import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

part 'leaderboard_state.dart';

/// Manages fetching and displaying leaderboard data for a daily game.
///
/// Handles async relay queries and tracks identity setup status.
/// Emits state changes for UI to listen to.
class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Creates a [LeaderboardCubit].
  LeaderboardCubit({
    required CommunityStatsRepository statsRepository,
    required NostrIdentityRepository identityRepository,
  }) : _statsRepository = statsRepository,
       _identityRepository = identityRepository,
       super(const LeaderboardState());

  final CommunityStatsRepository _statsRepository;
  final NostrIdentityRepository _identityRepository;

  /// Fetches leaderboard for the given [dTag].
  ///
  /// First checks if user has Nostr identity. If not, emits state with
  /// `hasIdentity=false` so UI can show identity setup prompt.
  /// If identity exists, fetches leaderboard from relays and emits
  /// loaded or unavailable state.
  Future<void> fetchLeaderboard(String dTag) async {
    try {
      final hasIdentity = await _identityRepository.hasIdentity();

      if (!hasIdentity) {
        emit(state.copyWith(hasIdentity: false));
        return;
      }

      emit(
        state.copyWith(
          status: LeaderboardStatus.loading,
          leaderboard: () => null,
        ),
      );

      final leaderboard = await _statsRepository.fetchLeaderboard(dTag);
      if (leaderboard != null) {
        emit(
          state.copyWith(
            status: LeaderboardStatus.loaded,
            leaderboard: () => leaderboard,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: LeaderboardStatus.unavailable,
            leaderboard: () => null,
          ),
        );
      }
    } on Exception {
      emit(
        state.copyWith(
          status: LeaderboardStatus.unavailable,
          leaderboard: () => null,
        ),
      );
    }
  }
}
