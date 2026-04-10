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
  /// Checks identity status but always fetches the global leaderboard
  /// regardless. Identity status is stored in state so the UI can
  /// show an optional setup prompt above the leaderboard.
  Future<void> fetchLeaderboard(String dTag) async {
    try {
      final hasIdentity = await _identityRepository.hasIdentity();

      emit(
        state.copyWith(
          status: LeaderboardStatus.loading,
          leaderboard: () => null,
          hasIdentity: hasIdentity,
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

  /// Merges followed users' scores into the existing leaderboard.
  ///
  /// Deduplicates by npub, marks followed entries, sorts by score DESC /
  /// createdAt ASC, and caps at 20 total entries with re-assigned ranks.
  Future<void> mergeFollowedScores(
    String dTag,
    Set<String> followedPubkeys,
  ) async {
    if (followedPubkeys.isEmpty) {
      emit(
        state.copyWith(
          followedPubkeys: followedPubkeys,
          followsStatus: LeaderboardStatus.loaded,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        followedPubkeys: followedPubkeys,
        followsStatus: LeaderboardStatus.loading,
      ),
    );

    try {
      final followedEntries = await _statsRepository.fetchScoresForAuthors(
        dTag,
        followedPubkeys.toList(),
      );

      final existingEntries =
          state.leaderboard?.entries ?? const <LeaderboardEntry>[];

      // Merge: existing global + followed, deduplicate by npub.
      final byNpub = <String, LeaderboardEntry>{};
      for (final entry in existingEntries) {
        byNpub[entry.npub] = entry;
      }
      for (final entry in followedEntries) {
        // Only add if not already in global list.
        byNpub.putIfAbsent(entry.npub, () => entry);
      }

      // Mark followed entries.
      final merged = byNpub.values.map((entry) {
        final pubkeyHex = decodePubkeyHex(entry.npub);
        final isFollowed =
            pubkeyHex != null && followedPubkeys.contains(pubkeyHex);
        return entry.copyWith(isFollowed: isFollowed);
      }).toList();

      // Sort: score DESC, then createdAt ASC.
      merged.sort((a, b) {
        final scoreComp = b.score.compareTo(a.score);
        if (scoreComp != 0) return scoreComp;
        return a.createdAt.compareTo(b.createdAt);
      });

      // Cap at 20 and re-assign ranks.
      final capped = merged.take(20).toList();
      for (var i = 0; i < capped.length; i++) {
        capped[i] = capped[i].copyWith(rank: i + 1);
      }

      final mergedLeaderboard = Leaderboard(
        dTag: state.leaderboard?.dTag ?? dTag,
        entries: capped,
      );

      emit(
        state.copyWith(
          leaderboard: () => mergedLeaderboard,
          followsStatus: LeaderboardStatus.loaded,
        ),
      );
    } on Exception {
      emit(state.copyWith(followsStatus: LeaderboardStatus.unavailable));
    }
  }
}
