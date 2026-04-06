import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/domain_layer/entities/broadcast_state.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';

class _MockNdk extends Mock implements Ndk {}

class _MockRequests extends Mock implements Requests {}

class _MockBroadcast extends Mock implements Broadcast {}

class _MockNostrSigner extends Mock implements NostrSigner {}

NdkBroadcastResponse _buildBroadcastResponse(
  Nip01Event event,
  List<RelayBroadcastResponse> relayResponses,
) {
  return NdkBroadcastResponse(
    publishEvent: event,
    broadcastDoneStream: Stream.value(relayResponses),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Nip01Event(pubKey: '', kind: 0, tags: [], content: ''),
    );
  });

  group('NostrDeletionRepository', () {
    late _MockNdk ndk;
    late _MockRequests requests;
    late _MockBroadcast broadcast;
    late NostrDeletionRepository repository;
    late _MockNostrSigner signer;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      broadcast = _MockBroadcast();
      signer = _MockNostrSigner();

      when(() => ndk.requests).thenReturn(requests);
      when(() => ndk.broadcast).thenReturn(broadcast);

      repository = NostrDeletionRepository(ndkProvider: NdkProvider(ndk: ndk));
    });

    group('queryUserEvents', () {
      test('returns list of event IDs on success', () async {
        final event1 = Nip01Event(
          id: 'event-1',
          pubKey: 'abc123',
          kind: 30042,
          tags: [],
          content: 'test',
        );
        final event2 = Nip01Event(
          id: 'event-2',
          pubKey: 'abc123',
          kind: 30042,
          tags: [],
          content: 'test',
        );

        when(
          () => requests.query(
            filter: any(named: 'filter'),
            explicitRelays: any(named: 'explicitRelays'),
            cacheRead: any(named: 'cacheRead'),
            cacheWrite: any(named: 'cacheWrite'),
          ),
        ).thenReturn(
          NdkResponse('test-id', Stream.fromIterable([event1, event2])),
        );

        final result = await repository.queryUserEvents('abc123');

        expect(result, equals(['event-1', 'event-2']));
      });

      test('returns empty list when no events found', () async {
        when(
          () => requests.query(
            filter: any(named: 'filter'),
            explicitRelays: any(named: 'explicitRelays'),
            cacheRead: any(named: 'cacheRead'),
            cacheWrite: any(named: 'cacheWrite'),
          ),
        ).thenReturn(NdkResponse('test-id', const Stream.empty()));

        final result = await repository.queryUserEvents('abc123');

        expect(result, isEmpty);
      });

      test('returns empty list on exception', () async {
        when(
          () => requests.query(
            filter: any(named: 'filter'),
            explicitRelays: any(named: 'explicitRelays'),
            cacheRead: any(named: 'cacheRead'),
            cacheWrite: any(named: 'cacheWrite'),
          ),
        ).thenThrow(Exception('network error'));

        final result = await repository.queryUserEvents('abc123');

        expect(result, isEmpty);
      });
    });

    group('deleteEvents', () {
      test('returns true when at least one relay accepts', () async {
        final signedEvent = Nip01Event(
          pubKey: 'abc123',
          kind: 5,
          tags: [
            ['e', 'event-1'],
            ['k', '30042'],
          ],
          content: 'Deleting game results',
        );

        when(() => signer.sign(any())).thenAnswer((_) async => signedEvent);

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          _buildBroadcastResponse(signedEvent, [
            RelayBroadcastResponse(
              relayUrl: 'wss://relay.damus.io',
              okReceived: true,
              broadcastSuccessful: true,
            ),
          ]),
        );

        final result = await repository.deleteEvents(
          eventIds: ['event-1'],
          signer: signer,
          pubKeyHex: 'abc123',
        );

        expect(result, isTrue);
      });

      test('returns false when all relays reject', () async {
        final signedEvent = Nip01Event(
          pubKey: 'abc123',
          kind: 5,
          tags: [
            ['e', 'event-1'],
            ['k', '30042'],
          ],
          content: 'Deleting game results',
        );

        when(() => signer.sign(any())).thenAnswer((_) async => signedEvent);

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          _buildBroadcastResponse(signedEvent, [
            RelayBroadcastResponse(
              relayUrl: 'wss://relay.damus.io',
              msg: 'blocked',
            ),
          ]),
        );

        final result = await repository.deleteEvents(
          eventIds: ['event-1'],
          signer: signer,
          pubKeyHex: 'abc123',
        );

        expect(result, isFalse);
      });

      test('returns false on exception', () async {
        when(() => signer.sign(any())).thenThrow(Exception('signing error'));

        final result = await repository.deleteEvents(
          eventIds: ['event-1'],
          signer: signer,
          pubKeyHex: 'abc123',
        );

        expect(result, isFalse);
      });

      test('creates event with correct tags for multiple event IDs', () async {
        final signedEvent = Nip01Event(
          pubKey: 'abc123',
          kind: 5,
          tags: [
            ['e', 'event-1'],
            ['e', 'event-2'],
            ['e', 'event-3'],
            ['k', '30042'],
          ],
          content: 'Deleting game results',
        );

        when(() => signer.sign(any())).thenAnswer((_) async => signedEvent);

        when(
          () => broadcast.broadcast(
            nostrEvent: any(named: 'nostrEvent'),
            specificRelays: any(named: 'specificRelays'),
          ),
        ).thenReturn(
          _buildBroadcastResponse(signedEvent, [
            RelayBroadcastResponse(
              relayUrl: 'wss://relay.damus.io',
              okReceived: true,
              broadcastSuccessful: true,
            ),
          ]),
        );

        await repository.deleteEvents(
          eventIds: ['event-1', 'event-2', 'event-3'],
          signer: signer,
          pubKeyHex: 'abc123',
        );

        final captured = verify(() => signer.sign(captureAny())).captured;
        final event = captured.first as Nip01Event;
        expect(event.tags, [
          ['e', 'event-1'],
          ['e', 'event-2'],
          ['e', 'event-3'],
          ['k', '30042'],
        ]);
      });
    });
  });
}
