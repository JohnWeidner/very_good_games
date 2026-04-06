import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';

/// Repository wrapping Ndk relay operations for querying and deleting
/// user events via NIP-09 (kind 5 deletion events).
class NostrDeletionRepository {
  /// Creates a [NostrDeletionRepository] with an [NdkProvider].
  NostrDeletionRepository({required NdkProvider ndkProvider})
    : _ndkProvider = ndkProvider;

  final NdkProvider _ndkProvider;

  /// Queries relays for the user's kind 30042 events.
  ///
  /// Returns a list of event IDs. Returns an empty list on failure or timeout.
  Future<List<String>> queryUserEvents(String pubKeyHex) async {
    try {
      final response = _ndkProvider.ndk.requests.query(
        filter: Filter(authors: [pubKeyHex], kinds: [30042], limit: 1000),
        explicitRelays: defaultRelayUrls,
        cacheRead: false,
        cacheWrite: false,
      );

      final events = await response.future.timeout(const Duration(seconds: 5));

      return events.map((e) => e.id).toList();
    } on Exception {
      return [];
    }
  }

  /// Creates and broadcasts a NIP-09 kind 5 deletion event for the given
  /// [eventIds].
  ///
  /// Returns `true` if at least one relay accepts the deletion event.
  /// Returns `false` on failure.
  Future<bool> deleteEvents({
    required List<String> eventIds,
    required NostrSigner signer,
    required String pubKeyHex,
  }) async {
    try {
      final tags = [
        for (final id in eventIds) ['e', id],
        ['k', '30042'],
      ];

      var event = Nip01Event(
        pubKey: pubKeyHex,
        kind: 5,
        tags: tags,
        content: 'Deleting game results',
      );

      event = await signer.sign(event);

      final response = _ndkProvider.ndk.broadcast.broadcast(
        nostrEvent: event,
        specificRelays: defaultRelayUrls,
      );

      final results = await response.broadcastDoneFuture.timeout(
        const Duration(seconds: 10),
      );

      return results.any((r) => r.okReceived);
    } on Exception {
      return false;
    }
  }
}
