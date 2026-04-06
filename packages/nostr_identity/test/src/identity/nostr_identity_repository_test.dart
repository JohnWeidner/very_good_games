import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:nostr_identity/nostr_identity.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('NostrIdentityRepository', () {
    late FlutterSecureStorage secureStorage;
    late NostrIdentityRepository repository;

    setUp(() {
      secureStorage = _MockFlutterSecureStorage();
      repository = NostrIdentityRepository(secureStorage: secureStorage);
    });

    group('generateKeyPair', () {
      test('stores private key and returns nsec', () async {
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        final result = await repository.generateKeyPair();

        expect(result.nsec, startsWith('nsec1'));
        expect(result.npub, startsWith('npub1'));
        verify(
          () => secureStorage.write(
            key: 'nostr_private_key_hex',
            value: any(named: 'value'),
          ),
        ).called(1);
      });

      test('throws when secure storage write fails', () async {
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(Exception('Storage failure'));

        expect(() => repository.generateKeyPair(), throwsException);
      });
    });

    group('importKey', () {
      late String validNsec;
      late String validPrivateKeyHex;

      setUp(() {
        final keyPair = Bip340.generatePrivateKey();
        validPrivateKeyHex = keyPair.privateKey!;
        validNsec = keyPair.privateKeyBech32!;
      });

      test('stores valid nsec and returns npub', () async {
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        final npub = await repository.importKey(validNsec);

        expect(npub, startsWith('npub1'));
        verify(
          () => secureStorage.write(
            key: 'nostr_private_key_hex',
            value: validPrivateKeyHex,
          ),
        ).called(1);
      });

      test('throws FormatException for invalid bech32', () async {
        expect(
          () => repository.importKey('not-a-valid-nsec'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for npub instead of nsec', () async {
        final keyPair = Bip340.generatePrivateKey();
        final npub = keyPair.publicKeyBech32!;

        expect(
          () => repository.importKey(npub),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('getPublicKey', () {
      test('returns npub when identity exists', () async {
        final keyPair = Bip340.generatePrivateKey();
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => keyPair.privateKey);

        final npub = await repository.getPublicKey();

        expect(npub, startsWith('npub1'));
      });

      test('returns null when no identity exists', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => null);

        final npub = await repository.getPublicKey();

        expect(npub, isNull);
      });
    });

    group('getPublicKeyHex', () {
      test('returns hex public key when identity exists', () async {
        final keyPair = Bip340.generatePrivateKey();
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => keyPair.privateKey);

        final hex = await repository.getPublicKeyHex();

        expect(hex, isNotNull);
        expect(hex!.length, equals(64));
      });

      test('returns null when no identity exists', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => null);

        final hex = await repository.getPublicKeyHex();

        expect(hex, isNull);
      });
    });

    group('hasIdentity', () {
      test('returns true when key exists', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => 'some-hex-key');

        final result = await repository.hasIdentity();

        expect(result, isTrue);
      });

      test('returns false when no key exists', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => null);

        final result = await repository.hasIdentity();

        expect(result, isFalse);
      });

      test('caches result after first call', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => 'some-hex-key');

        await repository.hasIdentity();
        await repository.hasIdentity();

        verify(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).called(1);
      });
    });

    group('deleteIdentity', () {
      test('deletes key from secure storage', () async {
        when(
          () => secureStorage.delete(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async {});

        await repository.deleteIdentity();

        verify(
          () => secureStorage.delete(key: 'nostr_private_key_hex'),
        ).called(1);
      });

      test('resets hasIdentity cache to false', () async {
        // First, set up identity.
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => secureStorage.delete(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async {});
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => null);

        await repository.generateKeyPair();
        await repository.deleteIdentity();
        final result = await repository.hasIdentity();

        expect(result, isFalse);
      });
    });

    group('getSigner', () {
      test('returns a LocalNostrSigner when identity exists', () async {
        final keyPair = Bip340.generatePrivateKey();
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => keyPair.privateKey);

        final signer = await repository.getSigner();

        expect(signer, isA<LocalNostrSigner>());
      });

      test('throws StateError when no identity exists', () async {
        when(
          () => secureStorage.read(key: 'nostr_private_key_hex'),
        ).thenAnswer((_) async => null);

        expect(() => repository.getSigner(), throwsA(isA<StateError>()));
      });
    });
  });
}
