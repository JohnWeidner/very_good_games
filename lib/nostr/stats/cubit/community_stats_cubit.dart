import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:very_good_games/nostr/stats/models/community_stats.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

part 'community_stats_state.dart';

/// Manages fetching and displaying community stats for a daily game.
class CommunityStatsCubit extends Cubit<CommunityStatsState> {
  /// Creates a [CommunityStatsCubit].
  CommunityStatsCubit({required CommunityStatsRepository statsRepository})
    : _statsRepository = statsRepository,
      super(const CommunityStatsState());

  final CommunityStatsRepository _statsRepository;

  /// Fetches community stats for the given [dTag].
  Future<void> fetchStats(String dTag) async {
    emit(state.copyWith(status: CommunityStatsStatus.loading));

    final stats = await _statsRepository.fetchStats(dTag);
    if (stats != null) {
      emit(state.copyWith(status: CommunityStatsStatus.loaded, stats: stats));
    } else {
      emit(const CommunityStatsState(status: CommunityStatsStatus.unavailable));
    }
  }
}
