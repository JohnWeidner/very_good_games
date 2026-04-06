import 'package:drift/drift.dart';

/// Drift table for cached Nostr kind-0 profile metadata.
class ProfileTable extends Table {
  @override
  String get tableName => 'profiles';

  /// Hex-encoded public key (primary key).
  TextColumn get pubkey => text()();

  /// Display name from kind-0 `name` field.
  TextColumn get name => text().nullable()();

  /// Profile picture URL from kind-0 `picture` field.
  TextColumn get picture => text().nullable()();

  /// Bio from kind-0 `about` field.
  TextColumn get about => text().nullable()();

  /// Full kind-0 content JSON, preserved for merge-on-write.
  TextColumn get rawJson => text().nullable()();

  /// Kind-0 event `created_at` (unix seconds).
  IntColumn get createdAt => integer().nullable()();

  /// Local timestamp of last relay fetch (unix seconds).
  IntColumn get lastFetchedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {pubkey};
}
