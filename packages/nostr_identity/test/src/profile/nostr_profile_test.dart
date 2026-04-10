import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';

void main() {
  group('NostrProfile', () {
    group('constructor', () {
      test('creates profile with all fields', () {
        const profile = NostrProfile(
          pubkey: 'abc123',
          name: 'Alice',
          picture: 'https://example.com/pic.jpg',
          about: 'Hello world',
          rawJson: '{"name":"Alice"}',
          createdAt: 1000,
        );

        expect(profile.pubkey, 'abc123');
        expect(profile.name, 'Alice');
        expect(profile.picture, 'https://example.com/pic.jpg');
        expect(profile.about, 'Hello world');
        expect(profile.rawJson, '{"name":"Alice"}');
        expect(profile.createdAt, 1000);
      });

      test('creates profile with only pubkey', () {
        const profile = NostrProfile(pubkey: 'abc123');

        expect(profile.pubkey, 'abc123');
        expect(profile.name, isNull);
        expect(profile.picture, isNull);
        expect(profile.about, isNull);
      });
    });

    group('fromEvent', () {
      test('parses kind-0 event with all fields', () {
        final content = jsonEncode({
          'name': 'Alice',
          'picture': 'https://example.com/pic.jpg',
          'about': 'Hello world',
        });

        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
          createdAt: 1000,
        );

        final profile = NostrProfile.fromEvent(event);

        expect(profile.pubkey, 'abc123');
        expect(profile.name, 'Alice');
        expect(profile.picture, 'https://example.com/pic.jpg');
        expect(profile.about, 'Hello world');
        expect(profile.rawJson, content);
        expect(profile.createdAt, 1000);
      });

      test('handles missing optional fields', () {
        final content = jsonEncode({'name': 'Bob'});

        final event = Nip01Event(
          pubKey: 'def456',
          kind: 0,
          tags: [],
          content: content,
        );

        final profile = NostrProfile.fromEvent(event);

        expect(profile.name, 'Bob');
        expect(profile.picture, isNull);
        expect(profile.about, isNull);
      });

      test('handles malformed JSON content gracefully', () {
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: 'not valid json',
        );

        final profile = NostrProfile.fromEvent(event);

        expect(profile.pubkey, 'abc123');
        expect(profile.name, isNull);
        expect(profile.rawJson, isNull);
      });

      test('handles empty content', () {
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: '',
        );

        final profile = NostrProfile.fromEvent(event);

        expect(profile.pubkey, 'abc123');
        expect(profile.name, isNull);
      });

      test('preserves unknown fields in rawJson', () {
        final content = jsonEncode({
          'name': 'Alice',
          'nip05': 'alice@example.com',
          'lud16': 'alice@getalby.com',
          'website': 'https://alice.dev',
        });

        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
        );

        final profile = NostrProfile.fromEvent(event);

        expect(profile.rawJson, content);
        final parsed = jsonDecode(profile.rawJson!) as Map<String, dynamic>;
        expect(parsed['nip05'], 'alice@example.com');
        expect(parsed['lud16'], 'alice@getalby.com');
      });
    });

    group('nip05', () {
      test('parses nip05 from event', () {
        final content = jsonEncode({
          'name': 'Alice',
          'nip05': 'alice@example.com',
        });
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
        );
        final profile = NostrProfile.fromEvent(event);

        expect(profile.nip05, 'alice@example.com');
      });

      test('returns null when event has no nip05', () {
        final content = jsonEncode({'name': 'Alice'});
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
        );
        final profile = NostrProfile.fromEvent(event);

        expect(profile.nip05, isNull);
      });

      test('stores nip05 from constructor', () {
        const profile = NostrProfile(
          pubkey: 'abc123',
          nip05: 'alice@example.com',
        );

        expect(profile.nip05, 'alice@example.com');
      });

      test('defaults to null', () {
        const profile = NostrProfile(pubkey: 'abc123');

        expect(profile.nip05, isNull);
      });
    });

    group('lud16', () {
      test('parses lud16 from event', () {
        final content = jsonEncode({
          'name': 'Alice',
          'lud16': 'alice@getalby.com',
        });
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
        );
        final profile = NostrProfile.fromEvent(event);

        expect(profile.lud16, 'alice@getalby.com');
      });

      test('returns null when event has no lud16', () {
        final content = jsonEncode({'name': 'Alice'});
        final event = Nip01Event(
          pubKey: 'abc123',
          kind: 0,
          tags: [],
          content: content,
        );
        final profile = NostrProfile.fromEvent(event);

        expect(profile.lud16, isNull);
      });

      test('defaults to null', () {
        const profile = NostrProfile(pubkey: 'abc123');

        expect(profile.lud16, isNull);
      });
    });

    group('lastFetchedAt', () {
      test('stores lastFetchedAt value', () {
        const profile = NostrProfile(pubkey: 'abc123', lastFetchedAt: 9999);

        expect(profile.lastFetchedAt, 9999);
      });

      test('defaults to null', () {
        const profile = NostrProfile(pubkey: 'abc123');

        expect(profile.lastFetchedAt, isNull);
      });

      test('is included in equality', () {
        const a = NostrProfile(pubkey: 'abc123', lastFetchedAt: 100);
        const b = NostrProfile(pubkey: 'abc123', lastFetchedAt: 200);

        expect(a, isNot(b));
      });
    });

    group('displayName', () {
      test('returns name when available', () {
        const profile = NostrProfile(pubkey: 'abc123', name: 'Alice');

        expect(profile.displayName, 'Alice');
      });

      test('returns truncated hex key when name is null', () {
        const profile = NostrProfile(
          pubkey:
              'aabbccddee112233445566778899aabb'
              'ccddee112233445566778899aabbccdd',
        );

        expect(profile.displayName, 'aabbccdd...aabbccdd');
      });

      test('returns full key when hex is short', () {
        const profile = NostrProfile(pubkey: 'short');

        expect(profile.displayName, 'short');
      });
    });

    group('toMergedJson', () {
      test('merges new fields into existing rawJson', () {
        final content = jsonEncode({
          'name': 'Alice',
          'nip05': 'alice@example.com',
          'lud16': 'alice@getalby.com',
        });

        final profile = NostrProfile(pubkey: 'abc123', rawJson: content);

        final merged = profile.toMergedJson(
          name: 'Alice Updated',
          about: 'New bio',
        );

        expect(merged['name'], 'Alice Updated');
        expect(merged['about'], 'New bio');
        // Preserved from original.
        expect(merged['nip05'], 'alice@example.com');
        expect(merged['lud16'], 'alice@getalby.com');
      });

      test('creates new JSON when rawJson is null', () {
        const profile = NostrProfile(pubkey: 'abc123');

        final merged = profile.toMergedJson(name: 'Alice', about: 'Hi');

        expect(merged['name'], 'Alice');
        expect(merged['about'], 'Hi');
        expect(merged.length, 2);
      });

      test('does not set null fields', () {
        const profile = NostrProfile(pubkey: 'abc123');

        final merged = profile.toMergedJson(name: 'Alice');

        expect(merged.containsKey('name'), isTrue);
        expect(merged.containsKey('about'), isFalse);
        expect(merged.containsKey('picture'), isFalse);
      });

      test('handles malformed rawJson gracefully', () {
        const profile = NostrProfile(
          pubkey: 'abc123',
          rawJson: 'not valid json',
        );

        final merged = profile.toMergedJson(name: 'Alice');

        expect(merged['name'], 'Alice');
        expect(merged.length, 1);
      });
    });

    group('equality', () {
      test('two profiles with same fields are equal', () {
        const a = NostrProfile(pubkey: 'abc', name: 'Alice');
        const b = NostrProfile(pubkey: 'abc', name: 'Alice');

        expect(a, b);
      });

      test('two profiles with different fields are not equal', () {
        const a = NostrProfile(pubkey: 'abc', name: 'Alice');
        const b = NostrProfile(pubkey: 'abc', name: 'Bob');

        expect(a, isNot(b));
      });
    });
  });
}
