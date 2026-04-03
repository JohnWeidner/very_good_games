import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/models/community_stats.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

class _MockCommunityStatsRepository extends Mock
    implements CommunityStatsRepository {}

void main() {
  group('CommunityStatsCubit', () {
    late CommunityStatsRepository repository;

    setUp(() {
      repository = _MockCommunityStatsRepository();
    });

    CommunityStatsCubit buildCubit() =>
        CommunityStatsCubit(statsRepository: repository);

    test('initial state is initial', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(CommunityStatsStatus.initial));
      expect(cubit.state.stats, isNull);
    });

    blocTest<CommunityStatsCubit, CommunityStatsState>(
      'emits [loading, loaded] when fetch returns stats',
      setUp: () {
        when(
          () => repository.fetchStats('guess-the-number:2026-04-02'),
        ).thenAnswer(
          (_) async => const CommunityStats(playerCount: 25, avgStars: 2.5),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchStats('guess-the-number:2026-04-02'),
      expect: () => [
        const CommunityStatsState(status: CommunityStatsStatus.loading),
        const CommunityStatsState(
          status: CommunityStatsStatus.loaded,
          stats: CommunityStats(playerCount: 25, avgStars: 2.5),
        ),
      ],
    );

    blocTest<CommunityStatsCubit, CommunityStatsState>(
      'emits [loading, unavailable] when fetch returns null',
      setUp: () {
        when(
          () => repository.fetchStats('guess-the-number:2026-04-02'),
        ).thenAnswer((_) async => null);
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchStats('guess-the-number:2026-04-02'),
      expect: () => [
        const CommunityStatsState(status: CommunityStatsStatus.loading),
        const CommunityStatsState(status: CommunityStatsStatus.unavailable),
      ],
    );
  });
}
