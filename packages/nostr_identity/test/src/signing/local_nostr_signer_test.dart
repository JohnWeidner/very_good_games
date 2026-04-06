import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:nostr_identity/nostr_identity.dart';

void main() {
  group('LocalNostrSigner', () {
    late KeyPair keyPair;
    late LocalNostrSigner signer;

    setUp(() {
      keyPair = Bip340.generatePrivateKey();
      signer = LocalNostrSigner(
        privateKeyHex: keyPair.privateKey!,
        publicKeyHex: keyPair.publicKey,
      );
    });

    test('signs an event and returns a signed copy', () async {
      final event = Nip01Event(
        pubKey: keyPair.publicKey,
        kind: 1,
        tags: [],
        content: 'test content',
      );

      final signed = await signer.sign(event);

      expect(signed.sig, isNotNull);
      expect(signed.sig, isNotEmpty);
      expect(signed.content, equals('test content'));
    });

    test('implements NostrSigner', () {
      expect(signer, isA<NostrSigner>());
    });
  });
}
