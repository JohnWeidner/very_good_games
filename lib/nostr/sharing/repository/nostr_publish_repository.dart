import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/relay/relay_config.dart';

/// Repository wrapping Ndk relay write operations.
///
/// Broadcasts signed events to the default relays and returns success
/// if at least one relay responds with OK.
class NostrPublishRepository {
  /// Creates a [NostrPublishRepository] with an existing [Ndk] instance.
  NostrPublishRepository({required Ndk ndk}) : _ndkFactory = null, _ndk = ndk;

  /// Creates a [NostrPublishRepository] that lazily initializes [Ndk]
  /// on first publish to avoid opening WebSocket connections at app startup.
  NostrPublishRepository.lazy() : _ndkFactory = _createNdk, _ndk = null;

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
      'NostrPublishRepository must be created with either ndk or lazy()',
    );
    _ndk ??= _ndkFactory!();
    return _ndk!;
  }

  /// Publishes a signed [event] to default relays.
  ///
  /// Returns `true` if at least one relay accepted the event.
  /// Returns `false` if all relays rejected or timed out.
  Future<bool> publish(Nip01Event event) async {
    try {
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
