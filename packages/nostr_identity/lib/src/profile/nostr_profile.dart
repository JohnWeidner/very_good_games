import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:ndk/ndk.dart';

/// A Nostr user profile parsed from a kind-0 event.
///
/// Preserves the full `rawJson` content for merge-on-write,
/// so publishing updates doesn't erase fields set by other clients.
class NostrProfile extends Equatable {
  /// Creates a [NostrProfile].
  const NostrProfile({
    required this.pubkey,
    this.name,
    this.picture,
    this.about,
    this.rawJson,
    this.createdAt,
  });

  /// Parses a [NostrProfile] from a kind-0 [Nip01Event].
  ///
  /// The event `content` is a stringified JSON object with optional
  /// `name`, `picture`, and `about` fields (NIP-01).
  factory NostrProfile.fromEvent(Nip01Event event) {
    String? name;
    String? picture;
    String? about;
    String? rawJson;

    try {
      final json = jsonDecode(event.content) as Map<String, dynamic>;
      name = json['name'] as String?;
      picture = json['picture'] as String?;
      about = json['about'] as String?;
      rawJson = event.content;
    } on FormatException {
      // Malformed JSON — create profile with pubkey only.
    }

    return NostrProfile(
      pubkey: event.pubKey,
      name: name,
      picture: picture,
      about: about,
      rawJson: rawJson,
      createdAt: event.createdAt,
    );
  }

  /// Hex-encoded public key.
  final String pubkey;

  /// Display name from kind-0 `name` field.
  final String? name;

  /// Profile picture URL from kind-0 `picture` field.
  final String? picture;

  /// Bio from kind-0 `about` field.
  final String? about;

  /// Full kind-0 content JSON, preserved for merge-on-write.
  final String? rawJson;

  /// Kind-0 event `created_at` timestamp (unix seconds).
  final int? createdAt;

  /// Display name with fallback to truncated npub.
  String get displayName => name ?? _truncateHexKey(pubkey);

  /// Merges the given fields into the existing [rawJson], preserving
  /// unknown fields (e.g. `nip05`, `lud16`, `website`).
  ///
  /// If [rawJson] is null, returns a new JSON map with only the
  /// provided fields.
  Map<String, dynamic> toMergedJson({
    String? name,
    String? picture,
    String? about,
  }) {
    Map<String, dynamic> base;
    try {
      base = rawJson != null
          ? jsonDecode(rawJson!) as Map<String, dynamic>
          : <String, dynamic>{};
    } on FormatException {
      base = <String, dynamic>{};
    }

    if (name != null) base['name'] = name;
    if (picture != null) base['picture'] = picture;
    if (about != null) base['about'] = about;

    return base;
  }

  static String _truncateHexKey(String hex) {
    if (hex.length <= 16) return hex;
    return '${hex.substring(0, 8)}...${hex.substring(hex.length - 8)}';
  }

  @override
  List<Object?> get props => [pubkey, name, picture, about, rawJson, createdAt];
}
