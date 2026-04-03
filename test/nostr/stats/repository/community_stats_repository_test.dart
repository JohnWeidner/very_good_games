import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

class _MockNdk extends Mock implements Ndk {}

class _MockRequests extends Mock implements Requests {}

void main() {
  group('CommunityStatsRepository', () {
    late Ndk ndk;
    late Requests requests;
    late CommunityStatsRepository repository;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      when(() => ndk.requests).thenReturn(requests);
      repository = CommunityStatsRepository(ndk: ndk);
    });

    Nip01Event makeEvent({
      required String pubKey,
      required int stars,
      int createdAt = 1000,
    }) {
      return Nip01Event(
        pubKey: pubKey,
        kind: 30042,
        tags: [
          ['d', 'guess-the-number:2026-04-02'],
          ['l', 'stars-$stars', 'games.vgg.score'],
        ],
        content: 'test',
        createdAt: createdAt,
      );
    }

    test('returns stats with correct player count and avg stars', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(
        NdkResponse(
          'test-id',
          Stream.fromIterable([
            makeEvent(pubKey: 'alice', stars: 3),
            makeEvent(pubKey: 'bob', stars: 2),
            makeEvent(pubKey: 'carol', stars: 1),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      expect(stats!.playerCount, equals(3));
      expect(stats.avgStars, equals(2.0));
    });

    test('deduplicates by pubkey keeping latest', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(
        NdkResponse(
          'test-id',
          Stream.fromIterable([
            makeEvent(pubKey: 'alice', stars: 1, createdAt: 100),
            makeEvent(pubKey: 'alice', stars: 3, createdAt: 200),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      expect(stats!.playerCount, equals(1));
      expect(stats.avgStars, equals(3.0));
    });

    test('returns null when no events found', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(NdkResponse('test-id', const Stream.empty()));

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNull);
    });

    test('returns null on exception', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenThrow(Exception('network error'));

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNull);
    });

    test('skips events with missing or malformed star labels', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(
        NdkResponse(
          'test-id',
          Stream.fromIterable([
            // Valid event.
            makeEvent(pubKey: 'alice', stars: 3),
            // Event with no l tags.
            Nip01Event(
              pubKey: 'bob',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-02'],
              ],
              content: 'test',
            ),
            // Event with malformed star value.
            Nip01Event(
              pubKey: 'carol',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-02'],
                ['l', 'stars-abc', 'games.vgg.score'],
              ],
              content: 'test',
            ),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      // Only alice counts — bob and carol have invalid star data.
      expect(stats!.playerCount, equals(1));
      expect(stats.avgStars, equals(3.0));
    });

    test('caches results by d tag', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenReturn(
        NdkResponse(
          'test-id',
          Stream.fromIterable([makeEvent(pubKey: 'alice', stars: 3)]),
        ),
      );

      // First call fetches from relays.
      await repository.fetchStats('guess-the-number:2026-04-02');
      // Second call uses cache.
      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      expect(stats!.playerCount, equals(1));

      // Only one query was made.
      verify(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).called(1);
    });
  });
}
