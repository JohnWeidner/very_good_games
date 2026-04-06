import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/nostr/stats/models/community_stats.dart';

void main() {
  group('CommunityStats', () {
    test('is equatable', () {
      const a = CommunityStats(playerCount: 10, avgScore: 2.5);
      const b = CommunityStats(playerCount: 10, avgScore: 2.5);
      const c = CommunityStats(playerCount: 5, avgScore: 1);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('props contains playerCount and avgScore', () {
      const stats = CommunityStats(playerCount: 10, avgScore: 2.5);
      expect(stats.props, equals([10, 2.5]));
    });
  });
}
