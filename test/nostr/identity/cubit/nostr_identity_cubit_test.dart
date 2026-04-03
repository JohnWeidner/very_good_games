import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/nostr/signing/signing.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrDeletionRepository extends Mock
    implements NostrDeletionRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(_MockNostrSigner());
  });

  group('NostrIdentityCubit', () {
    late NostrIdentityRepository identityRepository;
    late NostrDeletionRepository deletionRepository;

    setUp(() {
      identityRepository = _MockNostrIdentityRepository();
      deletionRepository = _MockNostrDeletionRepository();
    });

    NostrIdentityCubit buildCubit() => NostrIdentityCubit(
      identityRepository: identityRepository,
      deletionRepository: deletionRepository,
    );

    test('initial state is none', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(NostrIdentityStatus.none));
      expect(cubit.state.npub, isNull);
    });

    group('loadIdentity', () {
      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, ready] when identity exists',
        setUp: () {
          when(
            () => identityRepository.getPublicKey(),
          ).thenAnswer((_) async => 'npub1test');
        },
        build: buildCubit,
        act: (cubit) => cubit.loadIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.ready,
            npub: 'npub1test',
          ),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, none] when no identity exists',
        setUp: () {
          when(
            () => identityRepository.getPublicKey(),
          ).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.loadIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on exception',
        setUp: () {
          when(
            () => identityRepository.getPublicKey(),
          ).thenThrow(Exception('fail'));
        },
        build: buildCubit,
        act: (cubit) => cubit.loadIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Exception: fail',
          ),
        ],
      );
    });

    group('generateIdentity', () {
      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, ready] with npub and nsec on success',
        setUp: () {
          when(
            () => identityRepository.generateKeyPair(),
          ).thenAnswer((_) async => (nsec: 'nsec1test', npub: 'npub1test'));
        },
        build: buildCubit,
        act: (cubit) => cubit.generateIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.ready,
            npub: 'npub1test',
            nsec: 'nsec1test',
          ),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on exception',
        setUp: () {
          when(
            () => identityRepository.generateKeyPair(),
          ).thenThrow(Exception('storage fail'));
        },
        build: buildCubit,
        act: (cubit) => cubit.generateIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Exception: storage fail',
          ),
        ],
      );
    });

    group('importKey', () {
      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, ready] on valid nsec',
        setUp: () {
          when(
            () => identityRepository.importKey('nsec1valid'),
          ).thenAnswer((_) async => 'npub1imported');
        },
        build: buildCubit,
        act: (cubit) => cubit.importKey('nsec1valid'),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.ready,
            npub: 'npub1imported',
          ),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on FormatException',
        setUp: () {
          when(
            () => identityRepository.importKey('bad-key'),
          ).thenThrow(const FormatException('Invalid nsec key'));
        },
        build: buildCubit,
        act: (cubit) => cubit.importKey('bad-key'),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Invalid nsec key',
          ),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on generic Exception',
        setUp: () {
          when(
            () => identityRepository.importKey('nsec1fail'),
          ).thenThrow(Exception('storage fail'));
        },
        build: buildCubit,
        act: (cubit) => cubit.importKey('nsec1fail'),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Exception: storage fail',
          ),
        ],
      );
    });

    group('deleteIdentity', () {
      late NostrSigner signer;

      setUp(() {
        signer = _MockNostrSigner();
      });

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'queries relays and sends deletion before deleting local key',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => deletionRepository.queryUserEvents('abc123'),
          ).thenAnswer((_) async => ['event-1', 'event-2']);
          when(
            () => deletionRepository.deleteEvents(
              eventIds: any(named: 'eventIds'),
              signer: any(named: 'signer'),
              pubKeyHex: any(named: 'pubKeyHex'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => identityRepository.deleteIdentity(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.loading,
            deletionProgress: 'Searching for published results...',
          ),
          const NostrIdentityState(
            status: NostrIdentityStatus.loading,
            deletionProgress: 'Deleting 2 results from relays...',
          ),
          const NostrIdentityState(),
        ],
        verify: (_) {
          verify(
            () => deletionRepository.deleteEvents(
              eventIds: ['event-1', 'event-2'],
              signer: signer,
              pubKeyHex: 'abc123',
            ),
          ).called(1);
          verify(() => identityRepository.deleteIdentity()).called(1);
        },
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'skips deletion when no events found',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => deletionRepository.queryUserEvents('abc123'),
          ).thenAnswer((_) async => []);
          when(
            () => identityRepository.deleteIdentity(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.loading,
            deletionProgress: 'Searching for published results...',
          ),
          const NostrIdentityState(),
        ],
        verify: (_) {
          verifyNever(
            () => deletionRepository.deleteEvents(
              eventIds: any(named: 'eventIds'),
              signer: any(named: 'signer'),
              pubKeyHex: any(named: 'pubKeyHex'),
            ),
          );
          verify(() => identityRepository.deleteIdentity()).called(1);
        },
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'deletes local key even when relay query fails',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenThrow(StateError('No identity stored'));
          when(
            () => identityRepository.deleteIdentity(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(),
        ],
        verify: (_) {
          verify(() => identityRepository.deleteIdentity()).called(1);
        },
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'skips relay deletion when getPublicKeyHex returns null',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => null);
          when(
            () => identityRepository.deleteIdentity(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(),
        ],
        verify: (_) {
          verifyNever(() => deletionRepository.queryUserEvents(any()));
          verify(() => identityRepository.deleteIdentity()).called(1);
        },
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'deletes local key even when relay deletion fails',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => deletionRepository.queryUserEvents('abc123'),
          ).thenAnswer((_) async => ['event-1']);
          when(
            () => deletionRepository.deleteEvents(
              eventIds: any(named: 'eventIds'),
              signer: any(named: 'signer'),
              pubKeyHex: any(named: 'pubKeyHex'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => identityRepository.deleteIdentity(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.loading,
            deletionProgress: 'Searching for published results...',
          ),
          const NostrIdentityState(
            status: NostrIdentityStatus.loading,
            deletionProgress: 'Deleting 1 result from relays...',
          ),
          const NostrIdentityState(),
        ],
        verify: (_) {
          verify(() => identityRepository.deleteIdentity()).called(1);
        },
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits error when local key deletion fails',
        setUp: () {
          when(
            () => identityRepository.getSigner(),
          ).thenThrow(StateError('No identity stored'));
          when(
            () => identityRepository.deleteIdentity(),
          ).thenThrow(Exception('delete fail'));
        },
        build: buildCubit,
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Exception: delete fail',
          ),
        ],
      );
    });
  });
}
