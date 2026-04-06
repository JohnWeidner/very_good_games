import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/domain_layer/entities/broadcast_state.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';

class _MockNdk extends Mock implements Ndk {}

class _MockRequests extends Mock implements Requests {}

class _MockBroadcast extends Mock implements Broadcast {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Nip01Event(pubKey: '', kind: 0, tags: [], content: ''),
    );
  });

  group('NostrProfileRepository', () {
    late _MockNdk ndk;
    late _MockRequests requests;
    late _MockBroadcast broadcast;
    late NostrDatabase database;
    late NostrProfileRepository repository;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      broadcast = _MockBroadcast();
      when(() => ndk.requests).thenReturn(requests);
      when(() => ndk.broadcast).thenReturn(broadcast);
      database = NostrDatabase(NativeDatabase.memory());
      repository = NostrProfileRepository(
        ndkProvider: NdkProvider(ndk: ndk),
        database: database,
      );
    });

    tearDown(() async {
      await database.close();
    });

    Nip01Event makeKind0Event({
      required String pubKey,
      String? name,
      String? picture,
      String? about,
      Map<String, dynamic> extraFields = const {},
      int createdAt = 1000,
    }) {
      final json = <String, dynamic>{
        if (name != null) 'name': name,
        if (picture != null) 'picture': picture,
        if (about != null) 'about': about,
        ...extraFields,
      };
      return Nip01Event(
        pubKey: pubKey,
        kind: 0,
        tags: [],
        content: jsonEncode(json),
        createdAt: createdAt,
      );
    }

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

    void stubQueryThrows() {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenThrow(Exception('network error'));
    }

    group('getProfile', () {
      test('fetches from relay on cache miss', () async {
        stubQuery([makeKind0Event(pubKey: 'abc123', name: 'Alice')]);

        final profile = await repository.getProfile('abc123');

        expect(profile, isNotNull);
        expect(profile!.name, 'Alice');
        expect(profile.pubkey, 'abc123');
      });

      test('returns cached profile when fresh', () async {
        // First fetch populates cache.
        stubQuery([makeKind0Event(pubKey: 'abc123', name: 'Alice')]);
        await repository.getProfile('abc123');

        // Second fetch should use cache (no new relay call).
        stubQueryThrows();
        final profile = await repository.getProfile('abc123');

        expect(profile, isNotNull);
        expect(profile!.name, 'Alice');
      });

      test('returns null when relay returns no events', () async {
        stubQuery([]);

        final profile = await repository.getProfile('abc123');

        expect(profile, isNull);
      });

      test('returns null on relay exception with no cache', () async {
        stubQueryThrows();

        final profile = await repository.getProfile('abc123');

        expect(profile, isNull);
      });
    });

    group('getProfiles', () {
      test('returns empty map for empty input', () async {
        final result = await repository.getProfiles([]);

        expect(result, isEmpty);
      });

      test('batch-fetches from relay for cache misses', () async {
        stubQuery([
          makeKind0Event(pubKey: 'alice', name: 'Alice'),
          makeKind0Event(pubKey: 'bob', name: 'Bob'),
        ]);

        final result = await repository.getProfiles(['alice', 'bob']);

        expect(result, hasLength(2));
        expect(result['alice']!.name, 'Alice');
        expect(result['bob']!.name, 'Bob');
      });

      test('uses cache for fresh entries and fetches only stale', () async {
        // Populate cache for alice.
        stubQuery([makeKind0Event(pubKey: 'alice', name: 'Alice')]);
        await repository.getProfile('alice');

        // Now batch-fetch alice + bob.
        // Only bob should hit relay.
        stubQuery([makeKind0Event(pubKey: 'bob', name: 'Bob')]);

        final result = await repository.getProfiles(['alice', 'bob']);

        expect(result, hasLength(2));
        expect(result['alice']!.name, 'Alice');
        expect(result['bob']!.name, 'Bob');
      });

      test('returns partial results on relay failure', () async {
        // Populate cache for alice.
        stubQuery([makeKind0Event(pubKey: 'alice', name: 'Alice')]);
        await repository.getProfile('alice');

        // Relay fails for batch fetch.
        stubQueryThrows();

        final result = await repository.getProfiles(['alice', 'bob']);

        // Alice from cache, bob missing.
        expect(result, hasLength(1));
        expect(result['alice']!.name, 'Alice');
      });
    });

    group('publishProfile', () {
      late _MockNostrSigner signer;

      setUp(() {
        signer = _MockNostrSigner();
      });

      test('publishes merged profile and caches result', () async {
        // No existing profile.
        stubQuery([]);

        when(() => signer.sign(any())).thenAnswer((invocation) async {
          return invocation.positionalArguments[0] as Nip01Event;
        });

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          NdkBroadcastResponse(
            publishEvent: Nip01Event(
              pubKey: 'abc123',
              kind: 0,
              tags: [],
              content: '',
            ),
            broadcastDoneStream: Stream.value([
              RelayBroadcastResponse(
                relayUrl: 'wss://relay.damus.io',
                okReceived: true,
                broadcastSuccessful: true,
              ),
            ]),
          ),
        );

        final success = await repository.publishProfile(
          signer: signer,
          pubkeyHex: 'abc123',
          name: 'Alice',
          about: 'Hello',
        );

        expect(success, isTrue);

        // Verify it was cached.
        stubQueryThrows();
        final cached = await repository.getProfile('abc123');
        expect(cached, isNotNull);
        expect(cached!.name, 'Alice');
        expect(cached.about, 'Hello');
      });

      test('merges with existing profile', () async {
        // Existing profile has nip05 field.
        stubQuery([
          makeKind0Event(
            pubKey: 'abc123',
            name: 'Old Name',
            extraFields: {'nip05': 'alice@example.com'},
          ),
        ]);

        Nip01Event? signedEvent;
        when(() => signer.sign(any())).thenAnswer((invocation) async {
          signedEvent = invocation.positionalArguments[0] as Nip01Event;
          return signedEvent!;
        });

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          NdkBroadcastResponse(
            publishEvent: Nip01Event(
              pubKey: 'abc123',
              kind: 0,
              tags: [],
              content: '',
            ),
            broadcastDoneStream: Stream.value([
              RelayBroadcastResponse(
                relayUrl: 'wss://relay.damus.io',
                okReceived: true,
                broadcastSuccessful: true,
              ),
            ]),
          ),
        );

        await repository.publishProfile(
          signer: signer,
          pubkeyHex: 'abc123',
          name: 'New Name',
        );

        // Verify the signed event content preserves nip05.
        expect(signedEvent, isNotNull);
        final content =
            jsonDecode(signedEvent!.content) as Map<String, dynamic>;
        expect(content['name'], 'New Name');
        expect(content['nip05'], 'alice@example.com');
      });

      test('returns false on broadcast failure', () async {
        stubQuery([]);

        when(() => signer.sign(any())).thenAnswer((invocation) async {
          return invocation.positionalArguments[0] as Nip01Event;
        });

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          NdkBroadcastResponse(
            publishEvent: Nip01Event(
              pubKey: 'abc123',
              kind: 0,
              tags: [],
              content: '',
            ),
            broadcastDoneStream: Stream.value([
              RelayBroadcastResponse(
                relayUrl: 'wss://relay.damus.io',
                msg: 'blocked',
              ),
            ]),
          ),
        );

        final success = await repository.publishProfile(
          signer: signer,
          pubkeyHex: 'abc123',
          name: 'Alice',
        );

        expect(success, isFalse);
      });

      test('returns false on signer exception', () async {
        stubQuery([]);

        when(() => signer.sign(any())).thenThrow(Exception('signing failed'));

        final success = await repository.publishProfile(
          signer: signer,
          pubkeyHex: 'abc123',
          name: 'Alice',
        );

        expect(success, isFalse);
      });
    });

    group('deleteProfile', () {
      test('removes profile from cache', () async {
        // Populate cache.
        stubQuery([makeKind0Event(pubKey: 'abc123', name: 'Alice')]);
        await repository.getProfile('abc123');

        // Delete.
        await repository.deleteProfile('abc123');

        // Verify it's gone (relay also returns nothing).
        stubQuery([]);
        final profile = await repository.getProfile('abc123');
        expect(profile, isNull);
      });
    });
  });
}
