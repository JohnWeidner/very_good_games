import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/relay/relay_config.dart';

/// Provides a shared, lazily-initialized [Ndk] instance.
///
/// All Nostr repositories should use the same [NdkProvider] to avoid
/// opening multiple independent WebSocket connections to the same relays.
class NdkProvider {
  /// Creates an [NdkProvider] with an existing [Ndk] instance.
  NdkProvider({required Ndk ndk}) : _ndk = ndk;

  /// Creates an [NdkProvider] that lazily initializes [Ndk] on first access.
  NdkProvider.lazy() : _ndk = null;

  Ndk? _ndk;

  /// Returns the shared [Ndk] instance, creating it on first access.
  Ndk get ndk => _ndk ??= Ndk(
    NdkConfig(
      eventVerifier: Bip340EventVerifier(),
      cache: MemCacheManager(),
      bootstrapRelays: defaultRelayUrls,
    ),
  );
}
