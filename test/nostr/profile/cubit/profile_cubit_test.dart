import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/profile.dart';

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(_MockNostrSigner());
  });

  group('ProfileCubit', () {
    late NostrProfileRepository profileRepository;
    late NostrIdentityRepository identityRepository;

    setUp(() {
      profileRepository = _MockNostrProfileRepository();
      identityRepository = _MockNostrIdentityRepository();
    });

    ProfileCubit buildCubit() => ProfileCubit(
      profileRepository: profileRepository,
      identityRepository: identityRepository,
    );

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, ProfileStatus.initial);
      expect(cubit.state.profiles, isEmpty);
    });

    group('fetchProfiles', () {
      blocTest<ProfileCubit, ProfileState>(
        'does nothing for empty list',
        build: buildCubit,
        act: (cubit) => cubit.fetchProfiles([]),
        expect: () => <ProfileState>[],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits [loading, loaded] with profiles on success',
        setUp: () {
          when(() => profileRepository.getProfiles(any())).thenAnswer(
            (_) async => {
              'abc': const NostrProfile(pubkey: 'abc', name: 'Alice'),
            },
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.fetchProfiles(['abc']),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having((s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.profiles['abc']?.name, 'name', 'Alice'),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits loaded on exception (best-effort)',
        setUp: () {
          when(
            () => profileRepository.getProfiles(any()),
          ).thenThrow(Exception('fail'));
        },
        build: buildCubit,
        act: (cubit) => cubit.fetchProfiles(['abc']),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          const ProfileState(status: ProfileStatus.loaded),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'merges with existing profiles',
        seed: () => const ProfileState(
          status: ProfileStatus.loaded,
          profiles: {
            'existing': NostrProfile(pubkey: 'existing', name: 'Existing'),
          },
        ),
        setUp: () {
          when(() => profileRepository.getProfiles(any())).thenAnswer(
            (_) async => {
              'new': const NostrProfile(pubkey: 'new', name: 'New'),
            },
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.fetchProfiles(['new']),
        expect: () => [
          isA<ProfileState>().having(
            (s) => s.status,
            'status',
            ProfileStatus.loading,
          ),
          isA<ProfileState>()
              .having((s) => s.profiles.length, 'length', 2)
              .having(
                (s) => s.profiles['existing']?.name,
                'existing',
                'Existing',
              )
              .having((s) => s.profiles['new']?.name, 'new', 'New'),
        ],
      );
    });

    group('publishProfile', () {
      blocTest<ProfileCubit, ProfileState>(
        'emits [publishing, published] on success',
        setUp: () {
          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => profileRepository.publishProfile(
              signer: any(named: 'signer'),
              pubkeyHex: any(named: 'pubkeyHex'),
              name: any(named: 'name'),
              picture: any(named: 'picture'),
              about: any(named: 'about'),
            ),
          ).thenAnswer((_) async => true);
          when(() => profileRepository.getProfile('abc123')).thenAnswer(
            (_) async => const NostrProfile(pubkey: 'abc123', name: 'Alice'),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.publishProfile(name: 'Alice'),
        expect: () => [
          const ProfileState(status: ProfileStatus.publishing),
          isA<ProfileState>()
              .having((s) => s.status, 'status', ProfileStatus.published)
              .having((s) => s.profiles['abc123']?.name, 'name', 'Alice'),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits error when no identity available',
        setUp: () {
          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.publishProfile(name: 'Alice'),
        expect: () => [
          const ProfileState(status: ProfileStatus.publishing),
          const ProfileState(
            status: ProfileStatus.error,
            errorMessage: 'No identity available',
          ),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits error when publish fails',
        setUp: () {
          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => profileRepository.publishProfile(
              signer: any(named: 'signer'),
              pubkeyHex: any(named: 'pubkeyHex'),
              name: any(named: 'name'),
              picture: any(named: 'picture'),
              about: any(named: 'about'),
            ),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) => cubit.publishProfile(name: 'Alice'),
        expect: () => [
          const ProfileState(status: ProfileStatus.publishing),
          isA<ProfileState>().having(
            (s) => s.status,
            'status',
            ProfileStatus.error,
          ),
        ],
      );
    });

    group('fetchOwnProfile', () {
      blocTest<ProfileCubit, ProfileState>(
        'fetches own profile when identity exists',
        setUp: () {
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(() => profileRepository.getProfiles(any())).thenAnswer(
            (_) async => {
              'abc123': const NostrProfile(pubkey: 'abc123', name: 'Me'),
            },
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.fetchOwnProfile(),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>().having(
            (s) => s.profiles['abc123']?.name,
            'name',
            'Me',
          ),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'does nothing when no identity',
        setUp: () {
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.fetchOwnProfile(),
        expect: () => <ProfileState>[],
      );
    });
  });
}
