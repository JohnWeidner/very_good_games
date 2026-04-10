import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/stats/cubit/contact_list_cubit.dart';

class _MockContactListRepository extends Mock
    implements ContactListRepository {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

void main() {
  group('ContactListCubit', () {
    late _MockContactListRepository mockContactListRepository;
    late _MockNostrIdentityRepository mockIdentityRepository;

    setUp(() {
      mockContactListRepository = _MockContactListRepository();
      mockIdentityRepository = _MockNostrIdentityRepository();
    });

    test('initial state is correct', () {
      final cubit = ContactListCubit(
        contactListRepository: mockContactListRepository,
        identityRepository: mockIdentityRepository,
      );

      expect(cubit.state.status, ContactListStatus.initial);
      expect(cubit.state.followedPubkeys, isEmpty);
    });

    group('loadFollows', () {
      blocTest<ContactListCubit, ContactListState>(
        'emits unavailable when user has no identity',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => false);
        },
        build: () => ContactListCubit(
          contactListRepository: mockContactListRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.loadFollows(),
        expect: () => [
          const ContactListState(status: ContactListStatus.unavailable),
        ],
      );

      blocTest<ContactListCubit, ContactListState>(
        'emits unavailable when public key is null',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);
          when(
            () => mockIdentityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => null);
        },
        build: () => ContactListCubit(
          contactListRepository: mockContactListRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.loadFollows(),
        expect: () => [
          const ContactListState(status: ContactListStatus.loading),
          const ContactListState(status: ContactListStatus.unavailable),
        ],
      );

      blocTest<ContactListCubit, ContactListState>(
        'emits loaded with followed pubkeys on success',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);
          when(
            () => mockIdentityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'owner_hex');
          when(
            () => mockContactListRepository.getContactList('owner_hex'),
          ).thenAnswer(
            (_) async => const ContactList(
              ownerPubkey: 'owner_hex',
              followedPubkeys: {'alice', 'bob'},
              fetchedAt: 1000,
            ),
          );
        },
        build: () => ContactListCubit(
          contactListRepository: mockContactListRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.loadFollows(),
        expect: () => [
          const ContactListState(status: ContactListStatus.loading),
          const ContactListState(
            status: ContactListStatus.loaded,
            followedPubkeys: {'alice', 'bob'},
          ),
        ],
      );

      blocTest<ContactListCubit, ContactListState>(
        'emits loaded with empty set when no contact list found',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);
          when(
            () => mockIdentityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'owner_hex');
          when(
            () => mockContactListRepository.getContactList('owner_hex'),
          ).thenAnswer((_) async => null);
        },
        build: () => ContactListCubit(
          contactListRepository: mockContactListRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.loadFollows(),
        expect: () => [
          const ContactListState(status: ContactListStatus.loading),
          const ContactListState(status: ContactListStatus.loaded),
        ],
      );

      blocTest<ContactListCubit, ContactListState>(
        'emits unavailable on exception',
        setUp: () {
          when(
            () => mockIdentityRepository.hasIdentity(),
          ).thenThrow(Exception('error'));
        },
        build: () => ContactListCubit(
          contactListRepository: mockContactListRepository,
          identityRepository: mockIdentityRepository,
        ),
        act: (cubit) => cubit.loadFollows(),
        expect: () => [
          const ContactListState(status: ContactListStatus.unavailable),
        ],
      );
    });
  });

  group('ContactListState', () {
    test('copyWith creates new instance with overrides', () {
      const original = ContactListState();
      final updated = original.copyWith(
        status: ContactListStatus.loaded,
        followedPubkeys: {'alice'},
      );

      expect(updated.status, ContactListStatus.loaded);
      expect(updated.followedPubkeys, {'alice'});
    });

    test('copyWith preserves unchanged fields', () {
      const original = ContactListState(
        status: ContactListStatus.loaded,
        followedPubkeys: {'alice'},
      );

      final updated = original.copyWith(status: ContactListStatus.loading);

      expect(updated.status, ContactListStatus.loading);
      expect(updated.followedPubkeys, {'alice'});
    });

    test('equality works via Equatable', () {
      const a = ContactListState();
      const b = ContactListState();
      const c = ContactListState(status: ContactListStatus.loading);

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
