import 'package:ndk/ndk.dart';
import 'package:nostr_identity/src/signing/nostr_signer.dart';

/// A [NostrSigner] that signs events locally using [Bip340EventSigner].
///
/// This is the v1 implementation. Future versions may use NIP-46 bunker
/// signing via a different [NostrSigner] implementation.
class LocalNostrSigner implements NostrSigner {
  /// Creates a [LocalNostrSigner] from hex-encoded keys.
  LocalNostrSigner({
    required String privateKeyHex,
    required String publicKeyHex,
  }) : _signer = Bip340EventSigner(
         privateKey: privateKeyHex,
         publicKey: publicKeyHex,
       );

  final Bip340EventSigner _signer;

  @override
  Future<Nip01Event> sign(Nip01Event event) => _signer.sign(event);
}
