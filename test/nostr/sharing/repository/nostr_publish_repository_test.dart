import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/domain_layer/entities/broadcast_state.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';

class _MockNdk extends Mock implements Ndk {}

class _MockBroadcast extends Mock implements Broadcast {}

class _FakeNip01Event extends Fake implements Nip01Event {
  @override
  String get id => 'fake-id';
}

NdkBroadcastResponse _buildResponse(
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
    registerFallbackValue(_FakeNip01Event());
  });

  group('NostrPublishRepository', () {
    late Ndk ndk;
    late Broadcast broadcast;
    late NostrPublishRepository repository;
    late Nip01Event event;

    setUp(() {
      ndk = _MockNdk();
      broadcast = _MockBroadcast();
      when(() => ndk.broadcast).thenReturn(broadcast);
      repository = NostrPublishRepository(ndk: ndk);
      event = _FakeNip01Event();
    });

    test('returns true when at least one relay accepts', () async {
      when(
        () => broadcast.broadcast(
          nostrEvent: any(named: 'nostrEvent'),
          specificRelays: any(named: 'specificRelays'),
        ),
      ).thenReturn(
        _buildResponse(event, [
          RelayBroadcastResponse(
            relayUrl: 'wss://relay.damus.io',
            okReceived: true,
            broadcastSuccessful: true,
            msg: '',
          ),
          RelayBroadcastResponse(
            relayUrl: 'wss://nos.lol',
            okReceived: false,
            broadcastSuccessful: false,
            msg: 'timeout',
          ),
        ]),
      );

      final result = await repository.publish(event);
      expect(result, isTrue);
    });

    test('returns false when all relays reject', () async {
      when(
        () => broadcast.broadcast(
          nostrEvent: any(named: 'nostrEvent'),
          specificRelays: any(named: 'specificRelays'),
        ),
      ).thenReturn(
        _buildResponse(event, [
          RelayBroadcastResponse(
            relayUrl: 'wss://relay.damus.io',
            okReceived: false,
            broadcastSuccessful: false,
            msg: 'blocked',
          ),
        ]),
      );

      final result = await repository.publish(event);
      expect(result, isFalse);
    });

    test('returns false on exception', () async {
      when(
        () => broadcast.broadcast(
          nostrEvent: any(named: 'nostrEvent'),
          specificRelays: any(named: 'specificRelays'),
        ),
      ).thenThrow(Exception('network error'));

      final result = await repository.publish(event);
      expect(result, isFalse);
    });
  });
}
