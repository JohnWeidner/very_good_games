import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/ndk.dart' hide ContactList;
import 'package:nostr_identity/nostr_identity.dart';

class _MockNdk extends Mock implements Ndk {}

class _MockRequests extends Mock implements Requests {}

void main() {
  group('ContactListRepository', () {
    late Ndk ndk;
    late Requests requests;
    late ContactListRepository repository;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      when(() => ndk.requests).thenReturn(requests);
      repository = ContactListRepository(ndkProvider: NdkProvider(ndk: ndk));
    });

    void stubQuery(List<Nip01Event> events) {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(NdkResponse('test-id', Stream.fromIterable(events)));
    }

    Nip01Event makeKind3Event({
      required String pubKey,
      required List<String> followedPubkeys,
      int createdAt = 1000,
    }) {
      return Nip01Event(
        pubKey: pubKey,
        kind: 3,
        tags: [
          for (final pk in followedPubkeys) ['p', pk],
        ],
        content: '',
        createdAt: createdAt,
      );
    }

    group('getContactList', () {
      test('fetches kind-3 from relay and extracts followed pubkeys', () async {
        stubQuery([
          makeKind3Event(
            pubKey: 'owner',
            followedPubkeys: ['alice', 'bob', 'carol'],
          ),
        ]);

        final result = await repository.getContactList('owner');

        expect(result, isNotNull);
        expect(result!.ownerPubkey, 'owner');
        expect(result.followedPubkeys, {'alice', 'bob', 'carol'});
        expect(result.fetchedAt, isPositive);
      });

      test('returns null when no kind-3 event found', () async {
        stubQuery([]);

        final result = await repository.getContactList('owner');

        expect(result, isNull);
      });

      test('returns null on relay exception', () async {
        when(
          () => requests.query(
            filter: any(named: 'filter'),
            explicitRelays: any(named: 'explicitRelays'),
            cacheRead: any(named: 'cacheRead'),
            cacheWrite: any(named: 'cacheWrite'),
          ),
        ).thenThrow(Exception('network error'));

        final result = await repository.getContactList('owner');

        expect(result, isNull);
      });

      test('caps at 150 contacts from end of list', () async {
        final manyPubkeys = List.generate(
          200,
          (i) => 'pubkey_${i.toString().padLeft(3, '0')}',
        );

        stubQuery([
          makeKind3Event(pubKey: 'owner', followedPubkeys: manyPubkeys),
        ]);

        final result = await repository.getContactList('owner');

        expect(result, isNotNull);
        expect(result!.followedPubkeys, hasLength(150));
        // Should contain the last 150 entries (from index 50-199).
        expect(result.followedPubkeys.contains('pubkey_199'), isTrue);
        expect(result.followedPubkeys.contains('pubkey_050'), isTrue);
        // Should not contain the first 50 entries.
        expect(result.followedPubkeys.contains('pubkey_049'), isFalse);
        expect(result.followedPubkeys.contains('pubkey_000'), isFalse);
      });

      test('returns cached result on second call', () async {
        stubQuery([
          makeKind3Event(pubKey: 'owner', followedPubkeys: ['alice']),
        ]);

        await repository.getContactList('owner');

        // Relay now throws — second call should use cache.
        when(
          () => requests.query(
            filter: any(named: 'filter'),
            explicitRelays: any(named: 'explicitRelays'),
            cacheRead: any(named: 'cacheRead'),
            cacheWrite: any(named: 'cacheWrite'),
          ),
        ).thenThrow(Exception('should not be called'));

        final result = await repository.getContactList('owner');

        expect(result, isNotNull);
        expect(result!.followedPubkeys, {'alice'});
      });

      test('handles empty p tags gracefully', () async {
        stubQuery([
          Nip01Event(pubKey: 'owner', kind: 3, tags: [], content: ''),
        ]);

        final result = await repository.getContactList('owner');

        expect(result, isNotNull);
        expect(result!.followedPubkeys, isEmpty);
      });

      test('skips malformed p tags', () async {
        stubQuery([
          Nip01Event(
            pubKey: 'owner',
            kind: 3,
            tags: [
              ['p', 'alice'],
              ['p'], // Too short — skip.
              ['e', 'some-event'], // Not a p tag — skip.
              ['p', 'bob'],
            ],
            content: '',
          ),
        ]);

        final result = await repository.getContactList('owner');

        expect(result, isNotNull);
        expect(result!.followedPubkeys, {'alice', 'bob'});
      });
    });

    group('forceRefresh', () {
      test('bypasses cache and re-fetches from relay', () async {
        stubQuery([
          makeKind3Event(pubKey: 'owner', followedPubkeys: ['alice']),
        ]);

        await repository.getContactList('owner');

        // Force refresh with new data.
        stubQuery([
          makeKind3Event(pubKey: 'owner', followedPubkeys: ['alice', 'bob']),
        ]);

        final result = await repository.forceRefresh('owner');

        expect(result, isNotNull);
        expect(result!.followedPubkeys, {'alice', 'bob'});
      });
    });
  });

  group('ContactList', () {
    test('equality works via Equatable', () {
      const a = ContactList(
        ownerPubkey: 'owner',
        followedPubkeys: {'alice', 'bob'},
        fetchedAt: 1000,
      );
      const b = ContactList(
        ownerPubkey: 'owner',
        followedPubkeys: {'alice', 'bob'},
        fetchedAt: 1000,
      );
      const c = ContactList(
        ownerPubkey: 'owner',
        followedPubkeys: {'alice'},
        fetchedAt: 1000,
      );

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
