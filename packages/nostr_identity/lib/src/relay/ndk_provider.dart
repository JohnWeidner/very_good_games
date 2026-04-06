import 'package:ndk/ndk.dart';
import 'package:nostr_identity/src/relay/relay_config.dart';

/// Provides a shared, lazily-initialized [Ndk] instance.
///
/// All Nostr repositories should use the same [NdkProvider] to avoid
/// opening multiple independent WebSocket connections to the same relays.
class NdkProvider {
  /// Creates an [NdkProvider] with an existing [Ndk] instance.
  NdkProvider({required Ndk ndk}) : _ndk = ndk, _relayUrls = null;

  /// Creates an [NdkProvider] that lazily initializes [Ndk] on first access.
  ///
  /// Optionally accepts [relayUrls] to override the default relay list.
  NdkProvider.lazy({List<String>? relayUrls})
    : _ndk = null,
      _relayUrls = relayUrls;

  Ndk? _ndk;
  final List<String>? _relayUrls;

  /// Returns the shared [Ndk] instance, creating it on first access.
  Ndk get ndk => _ndk ??= Ndk(
    NdkConfig(
      eventVerifier: Bip340EventVerifier(),
      cache: MemCacheManager(),
      bootstrapRelays: _relayUrls ?? defaultRelayUrls,
    ),
  );
}
