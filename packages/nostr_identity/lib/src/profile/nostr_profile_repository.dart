import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/src/database/nostr_database.dart';
import 'package:nostr_identity/src/profile/nostr_profile.dart';
import 'package:nostr_identity/src/relay/ndk_provider.dart';
import 'package:nostr_identity/src/relay/relay_config.dart';
import 'package:nostr_identity/src/signing/nostr_signer.dart';

/// Repository for reading and writing Nostr kind-0 profile metadata.
///
/// Uses a Drift database for persistent caching with a 24-hour staleness
/// policy. Stale or missing profiles are fetched from relays.
///
/// Publishes use read-then-merge to preserve unknown fields set by
/// other Nostr clients (e.g. `nip05`, `lud16`, `website`).
class NostrProfileRepository {
  /// Creates a [NostrProfileRepository].
  NostrProfileRepository({
    required NdkProvider ndkProvider,
    required NostrDatabase database,
  }) : _ndkProvider = ndkProvider,
       _database = database;

  final NdkProvider _ndkProvider;
  final NostrDatabase _database;

  static const _staleDuration = Duration(hours: 24);
  static const _relayTimeout = Duration(seconds: 5);

  /// Fetches a single profile by [pubkeyHex].
  ///
  /// Returns cached if fresh (< 24h), else queries relays.
  /// Returns `null` if not found or relay timeout.
  Future<NostrProfile?> getProfile(String pubkeyHex) async {
    final cached = await _database.getProfile(pubkeyHex);
    if (cached != null && _isFresh(cached.lastFetchedAt)) {
      return _fromRow(cached);
    }

    try {
      final profile = await _fetchFromRelay(pubkeyHex);
      if (profile != null) {
        await _cacheProfile(profile);
        return profile;
      }

      // If relay returned nothing but we have a stale cache, return it.
      if (cached != null) return _fromRow(cached);
      return null;
    } on Exception {
      // On failure, return stale cache if available.
      if (cached != null) return _fromRow(cached);
      return null;
    }
  }

  /// Batch-fetches profiles for the given [pubkeyHexList].
  ///
  /// Returns cached profiles for fresh entries and queries relays
  /// only for stale or missing pubkeys.
  Future<Map<String, NostrProfile>> getProfiles(
    List<String> pubkeyHexList,
  ) async {
    if (pubkeyHexList.isEmpty) return {};

    final result = <String, NostrProfile>{};
    final toFetch = <String>[];

    // Check cache first.
    final cached = await _database.getProfiles(pubkeyHexList);
    final cachedByKey = {for (final row in cached) row.pubkey: row};

    for (final pubkey in pubkeyHexList) {
      final row = cachedByKey[pubkey];
      if (row != null && _isFresh(row.lastFetchedAt)) {
        result[pubkey] = _fromRow(row);
      } else {
        toFetch.add(pubkey);
      }
    }

    if (toFetch.isEmpty) return result;

    // Fetch missing/stale from relay.
    try {
      final fetched = await _batchFetchFromRelay(toFetch);
      for (final profile in fetched) {
        result[profile.pubkey] = profile;
        await _cacheProfile(profile);
      }

      // For pubkeys not returned by relay, use stale cache if available.
      for (final pubkey in toFetch) {
        if (!result.containsKey(pubkey)) {
          final stale = cachedByKey[pubkey];
          if (stale != null) result[pubkey] = _fromRow(stale);
        }
      }
    } on Exception {
      // On failure, use stale cache for anything available.
      for (final pubkey in toFetch) {
        final stale = cachedByKey[pubkey];
        if (stale != null) result[pubkey] = _fromRow(stale);
      }
    }

    return result;
  }

  /// Publishes an updated profile to relays using read-then-merge.
  ///
  /// Reads the existing kind-0 first, merges the new fields,
  /// signs, and broadcasts. Returns `true` on success.
  Future<bool> publishProfile({
    required NostrSigner signer,
    required String pubkeyHex,
    String? name,
    String? picture,
    String? about,
  }) async {
    try {
      // Read existing profile for merge.
      final existing = await getProfile(pubkeyHex);
      final profile = existing ?? NostrProfile(pubkey: pubkeyHex);

      final mergedJson = profile.toMergedJson(
        name: name,
        picture: picture,
        about: about,
      );
      final content = jsonEncode(mergedJson);

      var event = Nip01Event(
        pubKey: pubkeyHex,
        kind: 0,
        tags: [],
        content: content,
      );

      event = await signer.sign(event);

      final response = _ndkProvider.ndk.broadcast.broadcast(
        nostrEvent: event,
        specificRelays: defaultRelayUrls,
      );

      final results = await response.broadcastDoneFuture.timeout(
        const Duration(seconds: 10),
      );

      final success = results.any((r) => r.okReceived);

      if (success) {
        // Update local cache with the published profile.
        final published = NostrProfile(
          pubkey: pubkeyHex,
          name: mergedJson['name'] as String?,
          picture: mergedJson['picture'] as String?,
          about: mergedJson['about'] as String?,
          rawJson: content,
          createdAt: event.createdAt,
        );
        await _cacheProfile(published);
      }

      return success;
    } on Exception {
      return false;
    }
  }

  /// Deletes the cached profile for [pubkeyHex].
  Future<void> deleteProfile(String pubkeyHex) async {
    await _database.deleteProfile(pubkeyHex);
  }

  // -- Private helpers --

  bool _isFresh(int? lastFetchedAt) {
    if (lastFetchedAt == null) return false;
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(lastFetchedAt * 1000);
    return DateTime.now().toUtc().difference(fetchedAt) < _staleDuration;
  }

  Future<NostrProfile?> _fetchFromRelay(String pubkeyHex) async {
    final response = _ndkProvider.ndk.requests.query(
      filter: Filter(authors: [pubkeyHex], kinds: [0], limit: 1),
      explicitRelays: defaultRelayUrls,
      cacheRead: false,
      cacheWrite: false,
    );

    final events = await response.future.timeout(_relayTimeout);

    if (events.isEmpty) return null;
    return NostrProfile.fromEvent(events.first);
  }

  Future<List<NostrProfile>> _batchFetchFromRelay(
    List<String> pubkeyHexList,
  ) async {
    final response = _ndkProvider.ndk.requests.query(
      filter: Filter(
        authors: pubkeyHexList,
        kinds: [0],
        limit: pubkeyHexList.length,
      ),
      explicitRelays: defaultRelayUrls,
      cacheRead: false,
      cacheWrite: false,
    );

    final events = await response.future.timeout(_relayTimeout);

    return events.map(NostrProfile.fromEvent).toList();
  }

  Future<void> _cacheProfile(NostrProfile profile) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _database.upsertProfile(
      ProfileTableCompanion(
        pubkey: Value(profile.pubkey),
        name: Value(profile.name),
        picture: Value(profile.picture),
        about: Value(profile.about),
        rawJson: Value(profile.rawJson),
        createdAt: Value(profile.createdAt),
        lastFetchedAt: Value(now),
      ),
    );
  }

  NostrProfile _fromRow(ProfileTableData row) {
    return NostrProfile(
      pubkey: row.pubkey,
      name: row.name,
      picture: row.picture,
      about: row.about,
      rawJson: row.rawJson,
      createdAt: row.createdAt,
    );
  }
}
