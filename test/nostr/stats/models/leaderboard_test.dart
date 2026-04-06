import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';

void main() {
  group('LeaderboardEntry', () {
    test('displayName returns truncated npub', () {
      const entry = LeaderboardEntry(
        npub: 'npub1abcdefghijklmnopqrstuvwxyz0123456789',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );

      expect(entry.displayName, 'npub1abc...');
    });

    test('displayName handles short npub without truncation', () {
      const entry = LeaderboardEntry(
        npub: 'short',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );

      expect(entry.displayName, 'short');
    });

    test('copyWith creates new instance with overrides', () {
      const original = LeaderboardEntry(
        npub: 'npub123',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );

      final updated = original.copyWith(score: 200, rank: 2);

      expect(updated.npub, original.npub);
      expect(updated.score, 200);
      expect(updated.rank, 2);
      expect(updated.createdAt, original.createdAt);
    });

    test('copyWith with all null parameters returns equal instance', () {
      const entry = LeaderboardEntry(
        npub: 'npub123',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );

      final copy = entry.copyWith();

      expect(copy, entry);
    });

    test('equality works via Equatable', () {
      const entry1 = LeaderboardEntry(
        npub: 'npub123',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );
      const entry2 = LeaderboardEntry(
        npub: 'npub123',
        score: 100,
        rank: 1,
        createdAt: 123456789,
      );
      const entry3 = LeaderboardEntry(
        npub: 'npub123',
        score: 101,
        rank: 1,
        createdAt: 123456789,
      );

      expect(entry1, entry2);
      expect(entry1, isNot(entry3));
    });
  });

  group('Leaderboard', () {
    const entry1 = LeaderboardEntry(
      npub: 'npub1111',
      score: 100,
      rank: 1,
      createdAt: 100,
    );
    const entry2 = LeaderboardEntry(
      npub: 'npub2222',
      score: 90,
      rank: 2,
      createdAt: 200,
    );

    test('isEmpty returns true for empty leaderboard', () {
      const leaderboard = Leaderboard(dTag: 'test:2026-04-06', entries: []);

      expect(leaderboard.isEmpty, true);
    });

    test('isEmpty returns false for non-empty leaderboard', () {
      const leaderboard = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1, entry2],
      );

      expect(leaderboard.isEmpty, false);
    });

    test('containsUser returns false for non-existent pubkey', () {
      const leaderboard = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1, entry2],
      );

      // Use a valid 64-char hex pubkey that's not in the entries
      const hexPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      expect(leaderboard.containsUser(hexPubkey), false);
    });

    test('findUserEntry returns null for non-existent pubkey', () {
      const leaderboard = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1, entry2],
      );

      // Use a valid 64-char hex pubkey
      const hexPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      expect(leaderboard.findUserEntry(hexPubkey), isNull);
    });

    test('equality works via Equatable', () {
      const leaderboard1 = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1, entry2],
      );
      const leaderboard2 = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1, entry2],
      );
      const leaderboard3 = Leaderboard(
        dTag: 'test:2026-04-07',
        entries: [entry1, entry2],
      );

      expect(leaderboard1, leaderboard2);
      expect(leaderboard1, isNot(leaderboard3));
    });

    test('props includes all fields', () {
      const leaderboard = Leaderboard(
        dTag: 'test:2026-04-06',
        entries: [entry1],
      );

      expect(leaderboard.props, [leaderboard.dTag, leaderboard.entries]);
    });
  });
}
