import 'package:ndk/ndk.dart';

/// Abstract signer interface for Nostr events.
///
/// Decouples app code from ndk types so that a signer swap
/// (e.g. NIP-46 bunker, hardware) won't require ndk imports
/// in consuming code.
// Intentional single-member abstract class: signer implementations will
// vary (local, NIP-46 bunker, hardware) while sharing this interface.
// ignore: one_member_abstracts
abstract class NostrSigner {
  /// Signs the given [event] and returns the signed event.
  Future<Nip01Event> sign(Nip01Event event);
}
