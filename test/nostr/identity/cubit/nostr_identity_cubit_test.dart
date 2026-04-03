import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

void main() {
  group('NostrIdentityCubit', () {
    late NostrIdentityRepository repository;

    setUp(() {
      repository = _MockNostrIdentityRepository();
    });

    test('initial state is none', () {
      final cubit = NostrIdentityCubit(identityRepository: repository);
      expect(cubit.state.status, equals(NostrIdentityStatus.none));
      expect(cubit.state.npub, isNull);
    });

    group('loadIdentity', () {
      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, ready] when identity exists',
        setUp: () {
          when(
            () => repository.getPublicKey(),
          ).thenAnswer((_) async => 'npub1test');
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
          when(() => repository.getPublicKey()).thenAnswer((_) async => null);
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
        act: (cubit) => cubit.loadIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on exception',
        setUp: () {
          when(() => repository.getPublicKey()).thenThrow(Exception('fail'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
            () => repository.generateKeyPair(),
          ).thenAnswer((_) async => (nsec: 'nsec1test', npub: 'npub1test'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
            () => repository.generateKeyPair(),
          ).thenThrow(Exception('storage fail'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
            () => repository.importKey('nsec1valid'),
          ).thenAnswer((_) async => 'npub1imported');
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
            () => repository.importKey('bad-key'),
          ).thenThrow(const FormatException('Invalid nsec key'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
            () => repository.importKey('nsec1fail'),
          ).thenThrow(Exception('storage fail'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, none] on success',
        setUp: () {
          when(() => repository.deleteIdentity()).thenAnswer((_) async {});
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
        act: (cubit) => cubit.deleteIdentity(),
        expect: () => [
          const NostrIdentityState(status: NostrIdentityStatus.loading),
          const NostrIdentityState(),
        ],
      );

      blocTest<NostrIdentityCubit, NostrIdentityState>(
        'emits [loading, error] on exception',
        setUp: () {
          when(
            () => repository.deleteIdentity(),
          ).thenThrow(Exception('delete fail'));
        },
        build: () => NostrIdentityCubit(identityRepository: repository),
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
