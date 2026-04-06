import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_identity/nostr_identity.dart';

void main() {
  group('NostrDatabase', () {
    late NostrDatabase database;

    setUp(() {
      database = NostrDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    ProfileTableCompanion makeProfile({
      required String pubkey,
      String? name,
      String? picture,
      String? about,
      String? rawJson,
      int? createdAt,
      int? lastFetchedAt,
    }) {
      return ProfileTableCompanion(
        pubkey: Value(pubkey),
        name: Value(name),
        picture: Value(picture),
        about: Value(about),
        rawJson: Value(rawJson),
        createdAt: Value(createdAt),
        lastFetchedAt: Value(lastFetchedAt),
      );
    }

    group('upsertProfile', () {
      test('inserts a new profile', () async {
        await database.upsertProfile(
          makeProfile(pubkey: 'abc123', name: 'Alice'),
        );

        final result = await database.getProfile('abc123');

        expect(result, isNotNull);
        expect(result!.pubkey, 'abc123');
        expect(result.name, 'Alice');
      });

      test('updates an existing profile on conflict', () async {
        await database.upsertProfile(
          makeProfile(pubkey: 'abc123', name: 'Alice'),
        );
        await database.upsertProfile(
          makeProfile(pubkey: 'abc123', name: 'Alice Updated'),
        );

        final result = await database.getProfile('abc123');

        expect(result!.name, 'Alice Updated');
      });

      test('stores all fields', () async {
        await database.upsertProfile(
          makeProfile(
            pubkey: 'abc123',
            name: 'Alice',
            picture: 'https://example.com/pic.jpg',
            about: 'Hello',
            rawJson: '{"name":"Alice"}',
            createdAt: 1000,
            lastFetchedAt: 2000,
          ),
        );

        final result = await database.getProfile('abc123');

        expect(result!.name, 'Alice');
        expect(result.picture, 'https://example.com/pic.jpg');
        expect(result.about, 'Hello');
        expect(result.rawJson, '{"name":"Alice"}');
        expect(result.createdAt, 1000);
        expect(result.lastFetchedAt, 2000);
      });
    });

    group('getProfile', () {
      test('returns null for non-existent pubkey', () async {
        final result = await database.getProfile('nonexistent');

        expect(result, isNull);
      });
    });

    group('getProfiles', () {
      test('returns profiles for given pubkeys', () async {
        await database.upsertProfile(
          makeProfile(pubkey: 'alice', name: 'Alice'),
        );
        await database.upsertProfile(makeProfile(pubkey: 'bob', name: 'Bob'));
        await database.upsertProfile(
          makeProfile(pubkey: 'carol', name: 'Carol'),
        );

        final results = await database.getProfiles(['alice', 'carol']);

        expect(results, hasLength(2));
        expect(results.map((r) => r.name).toSet(), {'Alice', 'Carol'});
      });

      test('returns empty list for empty input', () async {
        final results = await database.getProfiles([]);

        expect(results, isEmpty);
      });

      test('skips non-existent pubkeys', () async {
        await database.upsertProfile(
          makeProfile(pubkey: 'alice', name: 'Alice'),
        );

        final results = await database.getProfiles(['alice', 'nonexistent']);

        expect(results, hasLength(1));
        expect(results.first.name, 'Alice');
      });
    });

    group('deleteProfile', () {
      test('deletes an existing profile', () async {
        await database.upsertProfile(
          makeProfile(pubkey: 'abc123', name: 'Alice'),
        );

        final deleted = await database.deleteProfile('abc123');

        expect(deleted, 1);

        final result = await database.getProfile('abc123');
        expect(result, isNull);
      });

      test('returns 0 for non-existent pubkey', () async {
        final deleted = await database.deleteProfile('nonexistent');

        expect(deleted, 0);
      });
    });

    test('schema version is 1', () {
      expect(database.schemaVersion, 1);
    });
  });
}
