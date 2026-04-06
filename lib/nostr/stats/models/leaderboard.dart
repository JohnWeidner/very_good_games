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

  /// Display name: truncated npub for v1 (alias support deferred to v2).
  String get displayName => _truncateNpub(npub);

  /// Truncates npub to first 8 characters + "..." for readability.
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
  const Leaderboard({required this.dTag, required this.entries});

  /// Game ID + date (e.g., 'guess-the-number:2026-04-06').
  final String dTag;

  /// Top N entries (1-10), sorted by rank.
  final List<LeaderboardEntry> entries;

  /// Whether the leaderboard has zero entries.
  bool get isEmpty => entries.isEmpty;

  /// Whether [userPubKeyHex] (hex) is in the top N.
  bool containsUser(String userPubKeyHex) {
    final userNpub = Nip19.encodePubKey(userPubKeyHex);
    return entries.any((e) => e.npub == userNpub);
  }

  /// Finds the entry for [userPubKeyHex] (hex), if present.
  LeaderboardEntry? findUserEntry(String userPubKeyHex) {
    final userNpub = Nip19.encodePubKey(userPubKeyHex);
    for (final entry in entries) {
      if (entry.npub == userNpub) {
        return entry;
      }
    }
    return null;
  }

  @override
  List<Object> get props => [dTag, entries];
}
