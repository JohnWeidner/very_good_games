import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

class _MockCommunityStatsRepository extends Mock
    implements CommunityStatsRepository {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

void main() {
  group('LeaderboardCubit', () {
    late _MockCommunityStatsRepository mockStatsRepository;
    late _MockNostrIdentityRepository mockIdentityRepository;

    setUp(() {
      mockStatsRepository = _MockCommunityStatsRepository();
      mockIdentityRepository = _MockNostrIdentityRepository();
    });

    test('initial state is correct', () {
      final cubit = LeaderboardCubit(
        statsRepository: mockStatsRepository,
        identityRepository: mockIdentityRepository,
      );

      expect(cubit.state.status, LeaderboardStatus.initial);
      expect(cubit.state.leaderboard, isNull);
      expect(cubit.state.hasIdentity, true);
    });

    group('fetchLeaderboard', () {
      blocTest<LeaderboardCubit, LeaderboardState>(
        'emits [LeaderboardState with hasIdentity=false] '
        'when user has no identity',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => false);
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.fetchLeaderboard('test:2026-04-06'),
        expect: () => [const LeaderboardState(hasIdentity: false)],
      );

      blocTest<LeaderboardCubit, LeaderboardState>(
        'emits [loading, loaded] when fetch succeeds',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          const entry = LeaderboardEntry(
            npub: 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            score: 100,
            rank: 1,
            createdAt: 1000,
          );
          const leaderboard = Leaderboard(
            dTag: 'test:2026-04-06',
            entries: [entry],
          );

          when(
            () => mockStatsRepository.fetchLeaderboard('test:2026-04-06'),
          ).thenAnswer((_) async => leaderboard);
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.fetchLeaderboard('test:2026-04-06'),
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having(
                (state) => state.status,
                'status',
                LeaderboardStatus.loaded,
              )
              .having((state) => state.leaderboard, 'leaderboard', isNotNull)
              .having((state) => state.leaderboard!.entries.length, 'length', 1)
              .having((state) => state.hasIdentity, 'hasIdentity', true),
        ],
      );

      blocTest<LeaderboardCubit, LeaderboardState>(
        'emits [loading, unavailable] when fetch returns null',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          when(
            () => mockStatsRepository.fetchLeaderboard('test:2026-04-06'),
          ).thenAnswer((_) async => null);
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.fetchLeaderboard('test:2026-04-06'),
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          const LeaderboardState(status: LeaderboardStatus.unavailable),
        ],
      );

      blocTest<LeaderboardCubit, LeaderboardState>(
        'catches exceptions and emits unavailable state',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          when(
            () => mockStatsRepository.fetchLeaderboard('test:2026-04-06'),
          ).thenThrow(Exception('Network error'));
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.fetchLeaderboard('test:2026-04-06'),
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          const LeaderboardState(status: LeaderboardStatus.unavailable),
        ],
      );

      blocTest<LeaderboardCubit, LeaderboardState>(
        'handles identity check exception gracefully',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenThrow(Exception('Storage error'));
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.fetchLeaderboard('test:2026-04-06'),
        expect: () => const [],
        errors: () => [isA<Exception>()],
      );

      blocTest<LeaderboardCubit, LeaderboardState>(
        'multiple calls replace previous state',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          when(
            () => mockStatsRepository.fetchLeaderboard('test1:2026-04-06'),
          ).thenAnswer(
            (_) async => const Leaderboard(
              dTag: 'test1:2026-04-06',
              entries: [
                LeaderboardEntry(
                  npub: 'npub1aaa',
                  score: 100,
                  rank: 1,
                  createdAt: 1000,
                ),
              ],
            ),
          );

          when(
            () => mockStatsRepository.fetchLeaderboard('test2:2026-04-06'),
          ).thenAnswer(
            (_) async => const Leaderboard(
              dTag: 'test2:2026-04-06',
              entries: [
                LeaderboardEntry(
                  npub: 'npub1bbb',
                  score: 200,
                  rank: 1,
                  createdAt: 2000,
                ),
              ],
            ),
          );
        },
        build: () => LeaderboardCubit(
          statsRepository: mockStatsRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) async {
          await cubit.fetchLeaderboard('test1:2026-04-06');
          await cubit.fetchLeaderboard('test2:2026-04-06');
        },
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          isA<LeaderboardState>().having(
            (state) => state.leaderboard?.dTag,
            'dTag',
            'test1:2026-04-06',
          ),
          const LeaderboardState(status: LeaderboardStatus.loading),
          isA<LeaderboardState>().having(
            (state) => state.leaderboard?.dTag,
            'dTag',
            'test2:2026-04-06',
          ),
        ],
      );
    });
  });

  group('LeaderboardState', () {
    test('copyWith creates new instance with overrides', () {
      const original = LeaderboardState(status: LeaderboardStatus.loaded);

      final updated = original.copyWith(
        status: LeaderboardStatus.unavailable,
        hasIdentity: false,
      );

      expect(updated.status, LeaderboardStatus.unavailable);
      expect(updated.hasIdentity, false);
    });

    test('copyWith preserves unchanged fields', () {
      const entry = LeaderboardEntry(
        npub: 'npub1test',
        score: 100,
        rank: 1,
        createdAt: 1000,
      );
      const leaderboard = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry],
      );
      const original = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: leaderboard,
      );

      final updated = original.copyWith(status: LeaderboardStatus.initial);

      expect(updated.leaderboard, leaderboard);
      expect(updated.hasIdentity, true);
      expect(updated.status, LeaderboardStatus.initial);
    });

    test('equality works via Equatable', () {
      const state1 = LeaderboardState();
      const state2 = LeaderboardState();
      const state3 = LeaderboardState(status: LeaderboardStatus.loading);

      expect(state1, state2);
      expect(state1, isNot(state3));
    });

    test('props includes all fields', () {
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        hasIdentity: false,
      );

      expect(state.props, [state.status, state.leaderboard, state.hasIdentity]);
    });
  });
}
