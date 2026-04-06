import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/relay/ndk_provider.dart';
import 'package:very_good_games/nostr/relay/relay_config.dart';
import 'package:very_good_games/nostr/stats/models/community_stats.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';

/// Repository wrapping Ndk relay read operations for community stats.
///
/// Fetches kind 30042 events for a given `d` tag, deduplicates by pubkey,
/// extracts scores from NIP-32 labels, and returns aggregate stats.
class CommunityStatsRepository {
  /// Creates a [CommunityStatsRepository] with an [NdkProvider].
  CommunityStatsRepository({required NdkProvider ndkProvider})
    : _ndkProvider = ndkProvider;

  final NdkProvider _ndkProvider;

  /// In-memory cache keyed by `d` tag.
  final _cache = <String, CommunityStats>{};

  /// Fetches community stats for the given [dTag].
  ///
  /// Returns cached results if available. Returns `null` on failure
  /// or if no events are found.
  Future<CommunityStats?> fetchStats(String dTag) async {
    if (_cache.containsKey(dTag)) return _cache[dTag];

    try {
      final response = _ndkProvider.ndk.requests.query(
        filter: Filter(kinds: [30042], dTags: [dTag], limit: 100),
        explicitRelays: defaultRelayUrls,
        cacheRead: false,
        cacheWrite: false,
      );

      final events = await response.future.timeout(const Duration(seconds: 5));

      if (events.isEmpty) return null;

      // Deduplicate by pubkey, keeping the latest created_at.
      final byPubkey = <String, Nip01Event>{};
      for (final event in events) {
        final existing = byPubkey[event.pubKey];
        if (existing == null || event.createdAt > existing.createdAt) {
          byPubkey[event.pubKey] = event;
        }
      }

      // Extract scores from NIP-32 labels.
      var totalScore = 0;
      var validCount = 0;
      for (final event in byPubkey.values) {
        final score = _extractScore(event);
        if (score != null) {
          totalScore += score;
          validCount++;
        }
      }

      if (validCount == 0) return null;

      final stats = CommunityStats(
        playerCount: validCount,
        avgScore: totalScore / validCount,
      );

      _cache[dTag] = stats;
      return stats;
    } on Exception {
      return null;
    }
  }

  /// Fetches the top [limit] leaderboard entries for [dTag].
  ///
  /// Queries kind 30042 events, deduplicates by pubkey (keeping latest),
  /// extracts scores, and sorts by score DESC then createdAt ASC.
  /// Returns null if no events found or relay timeout.
  Future<Leaderboard?> fetchLeaderboard(String dTag, {int limit = 10}) async {
    try {
      final response = _ndkProvider.ndk.requests.query(
        filter: Filter(kinds: [30042], dTags: [dTag], limit: 100),
        explicitRelays: defaultRelayUrls,
        cacheRead: false,
        cacheWrite: false,
      );

      final events = await response.future.timeout(const Duration(seconds: 5));

      if (events.isEmpty) return null;

      // Deduplicate by pubkey, keeping the latest created_at.
      final byPubkey = <String, Nip01Event>{};
      for (final event in events) {
        final existing = byPubkey[event.pubKey];
        if (existing == null || event.createdAt > existing.createdAt) {
          byPubkey[event.pubKey] = event;
        }
      }

      // Extract scores and build entries (without rank yet).
      final entries = <LeaderboardEntry>[];
      for (final event in byPubkey.values) {
        final score = _extractScore(event);
        if (score != null) {
          entries.add(
            LeaderboardEntry(
              npub: Nip19.encodePubKey(event.pubKey),
              score: score,
              rank: 0, // Placeholder; set after sorting
              createdAt: event.createdAt,
            ),
          );
        }
      }

      if (entries.isEmpty) return null;

      // Sort: score DESC, then createdAt ASC (deterministic tie-breaking).
      entries.sort((a, b) {
        final scoreComp = b.score.compareTo(a.score);
        if (scoreComp != 0) return scoreComp;
        return a.createdAt.compareTo(b.createdAt);
      });

      // Take top N and assign ranks.
      final top = entries.take(limit).toList();
      for (var i = 0; i < top.length; i++) {
        top[i] = top[i].copyWith(rank: i + 1);
      }

      return Leaderboard(dTag: dTag, entries: top);
    } on Exception {
      return null;
    }
  }

  /// Extracts the score from an event's NIP-32 `l` tags.
  static int? _extractScore(Nip01Event event) {
    for (final tag in event.tags) {
      if (tag.length >= 3 &&
          tag[0] == 'l' &&
          tag[2] == 'games.vgg.score' &&
          tag[1].startsWith('score-')) {
        return int.tryParse(tag[1].substring(6));
      }
    }
    return null;
  }
}
