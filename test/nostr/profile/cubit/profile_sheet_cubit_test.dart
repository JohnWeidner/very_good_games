import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/cubit/profile_sheet_cubit.dart';

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

void main() {
  group('ProfileSheetCubit', () {
    late _MockNostrProfileRepository mockProfileRepository;

    setUp(() {
      mockProfileRepository = _MockNostrProfileRepository();
    });

    const testProfile = NostrProfile(
      pubkey: 'abc123',
      name: 'Alice',
      picture: 'https://example.com/pic.jpg',
      about: 'Hello world',
      nip05: 'alice@example.com',
      lastFetchedAt: 1000,
    );

    test('initial state is correct', () {
      final cubit = ProfileSheetCubit(
        profileRepository: mockProfileRepository,
        pubkeyHex: 'abc123',
      );

      expect(cubit.state.status, ProfileSheetStatus.initial);
      expect(cubit.state.profile, isNull);
    });

    group('loadProfile', () {
      blocTest<ProfileSheetCubit, ProfileSheetState>(
        'emits [loading, loaded] on success',
        setUp: () {
          when(
            () => mockProfileRepository.getProfile('abc123'),
          ).thenAnswer((_) async => testProfile);
        },
        build: () => ProfileSheetCubit(
          profileRepository: mockProfileRepository,
          pubkeyHex: 'abc123',
        ),
        act: (cubit) => cubit.loadProfile(),
        expect: () => [
          const ProfileSheetState(status: ProfileSheetStatus.loading),
          const ProfileSheetState(
            status: ProfileSheetStatus.loaded,
            profile: testProfile,
          ),
        ],
      );

      blocTest<ProfileSheetCubit, ProfileSheetState>(
        'emits [loading, loaded with null] when profile not found',
        setUp: () {
          when(
            () => mockProfileRepository.getProfile('abc123'),
          ).thenAnswer((_) async => null);
        },
        build: () => ProfileSheetCubit(
          profileRepository: mockProfileRepository,
          pubkeyHex: 'abc123',
        ),
        act: (cubit) => cubit.loadProfile(),
        expect: () => [
          const ProfileSheetState(status: ProfileSheetStatus.loading),
          const ProfileSheetState(status: ProfileSheetStatus.loaded),
        ],
      );

      blocTest<ProfileSheetCubit, ProfileSheetState>(
        'emits [loading, error] on exception',
        setUp: () {
          when(
            () => mockProfileRepository.getProfile('abc123'),
          ).thenThrow(Exception('network error'));
        },
        build: () => ProfileSheetCubit(
          profileRepository: mockProfileRepository,
          pubkeyHex: 'abc123',
        ),
        act: (cubit) => cubit.loadProfile(),
        expect: () => [
          const ProfileSheetState(status: ProfileSheetStatus.loading),
          const ProfileSheetState(status: ProfileSheetStatus.error),
        ],
      );
    });

    group('refreshProfile', () {
      blocTest<ProfileSheetCubit, ProfileSheetState>(
        'calls getProfile with forceRefresh true',
        setUp: () {
          when(
            () => mockProfileRepository.getProfile('abc123'),
          ).thenAnswer((_) async => testProfile);
          when(
            () =>
                mockProfileRepository.getProfile('abc123', forceRefresh: true),
          ).thenAnswer(
            (_) async => const NostrProfile(
              pubkey: 'abc123',
              name: 'Alice Updated',
              lastFetchedAt: 2000,
            ),
          );
        },
        build: () => ProfileSheetCubit(
          profileRepository: mockProfileRepository,
          pubkeyHex: 'abc123',
        ),
        act: (cubit) async {
          await cubit.loadProfile();
          await cubit.refreshProfile();
        },
        expect: () => [
          const ProfileSheetState(status: ProfileSheetStatus.loading),
          const ProfileSheetState(
            status: ProfileSheetStatus.loaded,
            profile: testProfile,
          ),
          isA<ProfileSheetState>()
              .having((s) => s.status, 'status', ProfileSheetStatus.loading)
              .having(
                (s) => s.profile,
                'profile preserved during refresh',
                testProfile,
              ),
          isA<ProfileSheetState>()
              .having((s) => s.status, 'status', ProfileSheetStatus.loaded)
              .having((s) => s.profile?.name, 'name', 'Alice Updated'),
        ],
        verify: (_) {
          verify(
            () =>
                mockProfileRepository.getProfile('abc123', forceRefresh: true),
          ).called(1);
        },
      );
    });
  });

  group('ProfileSheetState', () {
    test('copyWith creates new instance with overrides', () {
      const original = ProfileSheetState();
      final updated = original.copyWith(status: ProfileSheetStatus.loaded);

      expect(updated.status, ProfileSheetStatus.loaded);
      expect(updated.profile, isNull);
    });

    test('copyWith can set profile to null', () {
      const profile = NostrProfile(pubkey: 'abc123', name: 'Alice');
      const original = ProfileSheetState(
        status: ProfileSheetStatus.loaded,
        profile: profile,
      );

      final updated = original.copyWith(profile: () => null);

      expect(updated.profile, isNull);
    });

    test('equality works via Equatable', () {
      const a = ProfileSheetState();
      const b = ProfileSheetState();
      const c = ProfileSheetState(status: ProfileSheetStatus.loading);

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
