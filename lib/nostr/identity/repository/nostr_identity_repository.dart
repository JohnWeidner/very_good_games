import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/helpers.dart';
import 'package:very_good_games/nostr/signing/signing.dart';

/// Repository managing Nostr identity (key pair) lifecycle.
///
/// All key material is stored in [FlutterSecureStorage] (iOS Keychain,
/// Android EncryptedSharedPreferences). No dual storage with
/// shared_preferences.
class NostrIdentityRepository {
  /// Creates a [NostrIdentityRepository].
  NostrIdentityRepository({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final FlutterSecureStorage _secureStorage;

  static const _privateKeyStorageKey = 'nostr_private_key_hex';

  /// In-memory cache for [hasIdentity] after first read.
  bool? _hasIdentityCache;

  /// Generates a new secp256k1 key pair, stores the private key hex in
  /// secure storage, and returns the nsec and npub (both bech32).
  ///
  /// Throws if secure storage write fails.
  Future<({String nsec, String npub})> generateKeyPair() async {
    final keyPair = Bip340.generatePrivateKey();
    final privateKeyHex = keyPair.privateKey;
    if (privateKeyHex == null) {
      throw StateError('Key generation returned null private key');
    }
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: privateKeyHex,
    );
    _hasIdentityCache = true;

    final nsec = Helpers.encodeBech32(privateKeyHex, 'nsec');
    final npub = Nip19.encodePubKey(keyPair.publicKey);
    return (nsec: nsec, npub: npub);
  }

  /// Imports a key from a bech32-encoded nsec string.
  ///
  /// Validates the bech32 encoding and that the decoded payload is a
  /// 32-byte hex string with the "nsec" prefix. Returns the derived npub.
  ///
  /// Throws [FormatException] if the nsec is invalid.
  /// Throws if secure storage write fails.
  Future<String> importKey(String nsec) async {
    final decoded = Helpers.decodeBech32(nsec);
    final hex = decoded[0];
    final hrp = decoded[1];

    if (hrp != 'nsec' || hex.isEmpty || hex.length != 64) {
      throw const FormatException('Invalid nsec key');
    }

    await _secureStorage.write(key: _privateKeyStorageKey, value: hex);
    _hasIdentityCache = true;

    final pubKeyHex = Bip340.getPublicKey(hex);
    return Nip19.encodePubKey(pubKeyHex);
  }

  /// Returns the npub (bech32) for the stored identity, or `null` if none.
  Future<String?> getPublicKey() async {
    final privateKeyHex = await _secureStorage.read(key: _privateKeyStorageKey);
    if (privateKeyHex == null || privateKeyHex.isEmpty) return null;

    final pubKeyHex = Bip340.getPublicKey(privateKeyHex);
    return Nip19.encodePubKey(pubKeyHex);
  }

  /// Whether an identity exists in secure storage.
  ///
  /// Caches the result in-memory after the first call.
  Future<bool> hasIdentity() async {
    if (_hasIdentityCache != null) return _hasIdentityCache!;

    final value = await _secureStorage.read(key: _privateKeyStorageKey);
    _hasIdentityCache = value != null && value.isNotEmpty;
    return _hasIdentityCache!;
  }

  /// Deletes the stored identity from secure storage.
  Future<void> deleteIdentity() async {
    await _secureStorage.delete(key: _privateKeyStorageKey);
    _hasIdentityCache = false;
  }

  /// Returns a [LocalNostrSigner] for the stored key.
  ///
  /// Throws [StateError] if no identity exists.
  Future<NostrSigner> getSigner() async {
    final privateKeyHex = await _secureStorage.read(key: _privateKeyStorageKey);
    if (privateKeyHex == null || privateKeyHex.isEmpty) {
      throw StateError('No identity stored');
    }

    final pubKeyHex = Bip340.getPublicKey(privateKeyHex);
    return LocalNostrSigner(
      privateKeyHex: privateKeyHex,
      publicKeyHex: pubKeyHex,
    );
  }
}
