import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/relay/ndk_provider.dart';
import 'package:very_good_games/nostr/relay/relay_config.dart';

/// Repository wrapping Ndk relay write operations.
///
/// Broadcasts signed events to the default relays and returns success
/// if at least one relay responds with OK.
class NostrPublishRepository {
  /// Creates a [NostrPublishRepository] with an [NdkProvider].
  NostrPublishRepository({required NdkProvider ndkProvider})
    : _ndkProvider = ndkProvider;

  final NdkProvider _ndkProvider;

  /// Publishes a signed [event] to default relays.
  ///
  /// Returns `true` if at least one relay accepted the event.
  /// Returns `false` if all relays rejected or timed out.
  Future<bool> publish(Nip01Event event) async {
    try {
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
