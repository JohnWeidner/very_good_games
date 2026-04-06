---
title: "feat: High Score Leaderboard — Part 1: Models & Repository"
date: 2026-04-06
type: implementation
status: ready
---

# High Score Leaderboard — Part 1: Models & Repository

## Overview

Implement immutable data models (`LeaderboardEntry`, `Leaderboard`) and extend `CommunityStatsRepository` with a `fetchLeaderboard()` method to query, deduplicate, and rank Nostr relay events.

**Part of:** High Score Leaderboard feature (see [brainstorm](../../brainstorm/2026-04-06-high-score-leaderboard-brainstorm-doc.md))

**Dependencies:** None. This PR is foundational.

---

## Problem & Scope

Players currently see only aggregate community stats; we need to fetch and rank individual top 10 scores from Nostr relays. This PR introduces the data layer needed by all downstream layers.

### Acceptance Criteria

- [ ] `LeaderboardEntry` model with npub, score, rank, createdAt; displayName property truncates npub
- [ ] `Leaderboard` model with entries list; helper methods (isEmpty, containsUser, findUserEntry)
- [ ] `CommunityStatsRepository.fetchLeaderboard(dTag, limit=10)` fetches kind 30042 events
- [ ] Deduplicates by pubkey (keeps latest event)
- [ ] Extracts scores from NIP-32 labels (reuses `_extractScore()` logic)
- [ ] Sorts by score DESC, then createdAt ASC (deterministic tie-breaking)
- [ ] Assigns ranks 1-10 to top entries
- [ ] Returns null on timeout (5s) or relay failure
- [ ] Gracefully handles empty results
- [ ] All unit tests pass (models + repository extension)
- [ ] Follows VGV conventions: Equatable, immutable models, copyWith pattern

---

## Technical Architecture

### Models: `lib/nostr/stats/models/leaderboard.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:ndk/ndk.dart';

/// A single entry in the leaderboard.
class LeaderboardEntry extends Equatable {
  /// Creates a [LeaderboardEntry].
  const LeaderboardEntry({
    required this.npub,
    required this.score,
    required this.rank,
    required this.createdAt,
  });

  /// User's public key (bech32 encoded).
  final String npub;

  /// Score value (numeric).
  final int score;

  /// Rank in leaderboard (1-10).
  final int rank;

  /// Nostr event creation timestamp (unix seconds).
  final int createdAt;

  /// Display name: alias if available, else truncated npub.
  String get displayName => _truncateNpub(npub);

  /// Truncates npub to first 8 + "..." for readability.
  static String _truncateNpub(String npub) {
    if (npub.length < 12) return npub;
    return '${npub.substring(0, 8)}...';
  }

  /// Creates a copy with optional field overrides.
  LeaderboardEntry copyWith({
    String? npub,
    int? score,
    int? rank,
    int? createdAt,
  }) {
    return LeaderboardEntry(
      npub: npub ?? this.npub,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object> get props => [npub, score, rank, createdAt];
}

/// Container for leaderboard data (top N entries, sorted).
class Leaderboard extends Equatable {
  /// Creates a [Leaderboard].
  const Leaderboard({
    required this.dTag,
    required this.entries,
  });

  /// Game ID + date (e.g., 'guess-the-number:2026-04-06').
  final String dTag;

  /// Top N entries (1-10), sorted by rank.
  final List<LeaderboardEntry> entries;

  /// Whether the leaderboard has zero entries.
  bool get isEmpty => entries.isEmpty;

  /// Whether [userPubKey] (hex) is in the top N.
  bool containsUser(String userPubKeyHex) {
    final userNpub = Nip19.encodePubKey(userPubKeyHex);
    return entries.any((e) => e.npub == userNpub);
  }

  /// Finds the entry for [userPubKey] (hex), if present.
  LeaderboardEntry? findUserEntry(String userPubKeyHex) {
    final userNpub = Nip19.encodePubKey(userPubKeyHex);
    return entries.firstWhereOrNull((e) => e.npub == userNpub);
  }

  @override
  List<Object> get props => [dTag, entries];
}
```

### Repository Extension: `lib/nostr/stats/repository/community_stats_repository.dart`

Add to the `CommunityStatsRepository` class:

```dart
/// Fetches the top [limit] leaderboard entries for [dTag].
///
/// Queries kind 30042 events, deduplicates by pubkey (keeping latest),
/// extracts scores, and sorts by score DESC then createdAt ASC.
/// Returns null if no events found or relay timeout.
Future<Leaderboard?> fetchLeaderboard(
  String dTag, {
  int limit = 10,
}) async {
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
        entries.add(LeaderboardEntry(
          npub: Nip19.encodePubKey(event.pubKey),
          score: score,
          rank: 0, // Placeholder; set after sorting
          createdAt: event.createdAt,
        ));
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
```

---

## Dependencies

None. This PR is independent and foundational.

---

## Testing Strategy

### Unit Tests: Models

**`test/nostr/stats/models/leaderboard_test.dart`** (~100 LOC)

- [ ] `LeaderboardEntry.displayName` returns alias if available (v2), else truncated npub
- [ ] `LeaderboardEntry.copyWith()` creates new instance with overrides
- [ ] `LeaderboardEntry` equality works via Equatable
- [ ] `Leaderboard.isEmpty` returns true when entries empty, false otherwise
- [ ] `Leaderboard.containsUser(hex)` returns true if pubkey in entries
- [ ] `Leaderboard.findUserEntry(hex)` returns entry or null
- [ ] `Leaderboard` equality works via Equatable
- [ ] Truncation logic handles edge cases (very short npubs)

### Unit Tests: Repository Extension

**`test/nostr/stats/repository/community_stats_repository_test.dart`** (extend existing, ~150 LOC for leaderboard tests)

- [ ] `fetchLeaderboard()` returns top 10 entries sorted by score DESC
- [ ] Tie-breaking: identical scores sorted by createdAt ASC (deterministic)
- [ ] Deduplication: keeps latest event per pubkey when multiple events from same user
- [ ] Rank assignment: assigns 1-10 to top entries in order
- [ ] Empty results: returns null when no valid entries
- [ ] Relay timeout (5s): returns null without throwing
- [ ] Exception handling: returns null on any NDK exception
- [ ] Score extraction: reuses existing `_extractScore()` logic correctly
- [ ] Partial scores: only counts entries with valid score labels
- [ ] Sorting stability: reproducible ranking on repeated queries with same data

Use `mocktail` for mocking `NdkProvider` and relay responses. Test with mock Nip01Event objects containing sample kind 30042 events with score labels.

---

## Implementation Checklist

- [ ] Create `lib/nostr/stats/models/leaderboard.dart` with both model classes
- [ ] Add `fetchLeaderboard()` method to `CommunityStatsRepository`
- [ ] Import `package:ndk/ndk.dart` for Nip19 encoding
- [ ] Import `package:collection/collection.dart` for `firstWhereOrNull`
- [ ] Create `test/nostr/stats/models/leaderboard_test.dart`
- [ ] Extend `test/nostr/stats/repository/community_stats_repository_test.dart` with leaderboard tests
- [ ] Update `lib/nostr/stats/models/` barrel file to export `leaderboard.dart`
- [ ] Run `dart fix --apply` and `dart format .`
- [ ] All tests pass

---

## Success Metrics

- ✅ Top 10 entries fetched, deduplicated, sorted deterministically
- ✅ 5-second relay timeout prevents hanging
- ✅ Graceful null return on any failure (no exceptions bubbling up)
- ✅ 100% unit test coverage for models and new repository method
- ✅ Code follows VGV conventions (Equatable, immutable, copyWith)

---

## Next Steps

Once this PR is merged:
1. Part 2 builds state management (LeaderboardCubit) on top of this repository method
2. Part 3 creates the UI widget
3. Part 4 integrates into game results overlays
