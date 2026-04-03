import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/relay/relay_config.dart';
import 'package:very_good_games/nostr/signing/signing.dart';

/// Repository wrapping Ndk relay operations for querying and deleting
/// user events via NIP-09 (kind 5 deletion events).
class NostrDeletionRepository {
  /// Creates a [NostrDeletionRepository] with an existing [Ndk] instance.
  NostrDeletionRepository({required Ndk ndk}) : _ndkFactory = null, _ndk = ndk;

  /// Creates a [NostrDeletionRepository] that lazily initializes [Ndk]
  /// on first use to avoid opening WebSocket connections at app startup.
  NostrDeletionRepository.lazy() : _ndkFactory = _createNdk, _ndk = null;

  static Ndk _createNdk() {
    return Ndk(
      NdkConfig(
        eventVerifier: Bip340EventVerifier(),
        cache: MemCacheManager(),
        bootstrapRelays: defaultRelayUrls,
      ),
    );
  }

  final Ndk Function()? _ndkFactory;
  Ndk? _ndk;

  Ndk get _resolvedNdk {
    assert(
      _ndk != null || _ndkFactory != null,
      'NostrDeletionRepository must be created with either ndk or lazy()',
    );
    _ndk ??= _ndkFactory!();
    return _ndk!;
  }

  /// Queries relays for the user's kind 30042 events.
  ///
  /// Returns a list of event IDs. Returns an empty list on failure or timeout.
  Future<List<String>> queryUserEvents(String pubKeyHex) async {
    try {
      final response = _resolvedNdk.requests.query(
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

      final response = _resolvedNdk.broadcast.broadcast(
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
