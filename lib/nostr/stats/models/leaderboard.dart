import 'package:equatable/equatable.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/helpers.dart' show Helpers;

/// A single entry in the leaderboard.
class LeaderboardEntry extends Equatable {
  /// Creates a [LeaderboardEntry].
  const LeaderboardEntry({
    required this.npub,
    required this.score,
    required this.rank,
    required this.createdAt,
    this.isFollowed = false,
  });

  /// User's public key (bech32 encoded).
  final String npub;

  /// Score value (numeric).
  final int score;

  /// Rank in leaderboard (1-10).
  final int rank;

  /// Nostr event creation timestamp (unix seconds).
  final int createdAt;

  /// Whether this user is followed by the current user.
  final bool isFollowed;

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
    bool? isFollowed,
  }) {
    return LeaderboardEntry(
      npub: npub ?? this.npub,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      createdAt: createdAt ?? this.createdAt,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }

  @override
  List<Object> get props => [npub, score, rank, createdAt, isFollowed];
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

/// Decodes a bech32 npub to hex pubkey.
///
/// Returns `null` if decoding fails.
String? decodePubkeyHex(String npub) {
  try {
    final decoded = Helpers.decodeBech32(npub);
    if (decoded[1] == 'npub') return decoded[0];
    return null;
  } on Exception {
    return null;
  }
}
