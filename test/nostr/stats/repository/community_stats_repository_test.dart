import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';
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
      repository = CommunityStatsRepository(ndkProvider: NdkProvider(ndk: ndk));
    });

    Nip01Event makeEvent({
      required String pubKey,
      required int score,
      int createdAt = 1000,
    }) {
      return Nip01Event(
        pubKey: pubKey,
        kind: 30042,
        tags: [
          ['d', 'guess-the-number:2026-04-02'],
          ['l', 'score-$score', 'games.vgg.score'],
        ],
        content: 'test',
        createdAt: createdAt,
      );
    }

    test('returns stats with correct player count and avg score', () async {
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
            makeEvent(pubKey: 'alice', score: 3),
            makeEvent(pubKey: 'bob', score: 2),
            makeEvent(pubKey: 'carol', score: 1),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      expect(stats!.playerCount, equals(3));
      expect(stats.avgScore, equals(2.0));
    });

    test('deduplicates by pubkey keeping oldest (first submission)', () async {
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
            makeEvent(pubKey: 'alice', score: 1, createdAt: 100),
            makeEvent(pubKey: 'alice', score: 3, createdAt: 200),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      expect(stats!.playerCount, equals(1));
      // Keeps the oldest event (createdAt: 100, score: 1).
      expect(stats.avgScore, equals(1.0));
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

    test('skips events with missing or malformed score labels', () async {
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
            makeEvent(pubKey: 'alice', score: 3),
            // Event with no l tags.
            Nip01Event(
              pubKey: 'bob',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-02'],
              ],
              content: 'test',
            ),
            // Event with malformed score value.
            Nip01Event(
              pubKey: 'carol',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-02'],
                ['l', 'score-abc', 'games.vgg.score'],
              ],
              content: 'test',
            ),
          ]),
        ),
      );

      final stats = await repository.fetchStats('guess-the-number:2026-04-02');

      expect(stats, isNotNull);
      // Only alice counts — bob and carol have invalid score data.
      expect(stats!.playerCount, equals(1));
      expect(stats.avgScore, equals(3.0));
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
          Stream.fromIterable([makeEvent(pubKey: 'alice', score: 3)]),
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

  group('CommunityStatsRepository.fetchLeaderboard', () {
    final pubKeyA = 'a' * 64;
    final pubKeyB = 'b' * 64;
    final pubKeyC = 'c' * 64;

    late Ndk ndk;
    late Requests requests;
    late CommunityStatsRepository repository;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      when(() => ndk.requests).thenReturn(requests);
      repository = CommunityStatsRepository(ndkProvider: NdkProvider(ndk: ndk));
    });

    Nip01Event makeEvent({
      required String pubKey,
      required int score,
      int createdAt = 1000,
    }) {
      return Nip01Event(
        pubKey: pubKey,
        kind: 30042,
        tags: [
          ['d', 'guess-the-number:2026-04-06'],
          ['l', 'score-$score', 'games.vgg.score'],
        ],
        content: 'test',
        createdAt: createdAt,
      );
    }

    test('returns top entries sorted by score DESC', () async {
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
            makeEvent(pubKey: pubKeyA, score: 100),
            makeEvent(pubKey: pubKeyB, score: 90),
            makeEvent(pubKey: pubKeyC, score: 110),
          ]),
        ),
      );

      final leaderboard = await repository.fetchLeaderboard(
        'guess-the-number:2026-04-06',
      );

      expect(leaderboard, isNotNull);
      expect(leaderboard!.entries, hasLength(3));
      expect(leaderboard.entries[0].score, equals(110)); // Highest
      expect(leaderboard.entries[0].rank, equals(1));
      expect(leaderboard.entries[1].score, equals(100));
      expect(leaderboard.entries[1].rank, equals(2));
      expect(leaderboard.entries[2].score, equals(90)); // Lowest
      expect(leaderboard.entries[2].rank, equals(3));
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

      final leaderboard = await repository.fetchLeaderboard(
        'guess-the-number:2026-04-06',
      );

      expect(leaderboard, isNull);
    });

    test('returns null on exception', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenThrow(Exception('relay error'));

      final leaderboard = await repository.fetchLeaderboard(
        'guess-the-number:2026-04-06',
      );

      expect(leaderboard, isNull);
    });

    test('returns null when all entries lack valid scores', () async {
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
            Nip01Event(
              pubKey: 'alice',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-06'],
              ],
              content: 'test',
            ),
            Nip01Event(
              pubKey: 'bob',
              kind: 30042,
              tags: [
                ['d', 'guess-the-number:2026-04-06'],
              ],
              content: 'test',
            ),
          ]),
        ),
      );

      final leaderboard = await repository.fetchLeaderboard(
        'guess-the-number:2026-04-06',
      );

      expect(leaderboard, isNull);
    });
  });

  group('CommunityStatsRepository.fetchScoresForAuthors', () {
    final pubKeyA = 'a' * 64;
    final pubKeyB = 'b' * 64;

    late Ndk ndk;
    late Requests requests;
    late CommunityStatsRepository repository;

    setUp(() {
      ndk = _MockNdk();
      requests = _MockRequests();
      when(() => ndk.requests).thenReturn(requests);
      repository = CommunityStatsRepository(ndkProvider: NdkProvider(ndk: ndk));
    });

    Nip01Event makeEvent({
      required String pubKey,
      required int score,
      int createdAt = 1000,
    }) {
      return Nip01Event(
        pubKey: pubKey,
        kind: 30042,
        tags: [
          ['d', 'test:2026-04-10'],
          ['l', 'score-$score', 'games.vgg.score'],
        ],
        content: 'test',
        createdAt: createdAt,
      );
    }

    test('returns entries for given authors', () async {
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
            makeEvent(pubKey: pubKeyA, score: 100),
            makeEvent(pubKey: pubKeyB, score: 80),
          ]),
        ),
      );

      final entries = await repository.fetchScoresForAuthors(
        'test:2026-04-10',
        [pubKeyA, pubKeyB],
      );

      expect(entries, hasLength(2));
      expect(entries[0].score, 100);
      expect(entries[1].score, 80);
    });

    test('returns empty list for empty authors', () async {
      final entries = await repository.fetchScoresForAuthors(
        'test:2026-04-10',
        [],
      );

      expect(entries, isEmpty);
    });

    test('deduplicates by pubkey keeping oldest', () async {
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
            makeEvent(pubKey: pubKeyA, score: 50, createdAt: 200),
            makeEvent(pubKey: pubKeyA, score: 100, createdAt: 100),
          ]),
        ),
      );

      final entries = await repository.fetchScoresForAuthors(
        'test:2026-04-10',
        [pubKeyA],
      );

      expect(entries, hasLength(1));
      // Keeps oldest (createdAt: 100, score: 100).
      expect(entries[0].score, 100);
    });

    test('returns partial results on exception', () async {
      when(
        () => requests.query(
          filter: any(named: 'filter'),
          explicitRelays: any(named: 'explicitRelays'),
          cacheRead: any(named: 'cacheRead'),
          cacheWrite: any(named: 'cacheWrite'),
        ),
      ).thenThrow(Exception('network error'));

      final entries = await repository.fetchScoresForAuthors(
        'test:2026-04-10',
        [pubKeyA],
      );

      expect(entries, isEmpty);
    });
  });
}
