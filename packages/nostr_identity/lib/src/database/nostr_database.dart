import 'package:drift/drift.dart';
import 'package:nostr_identity/src/database/profile_table.dart';

part 'nostr_database.g.dart';

/// Drift database for the nostr_identity package.
///
/// Schema version 1: profiles table only.
@DriftDatabase(tables: [ProfileTable])
class NostrDatabase extends _$NostrDatabase {
  /// Creates a [NostrDatabase] with the given [QueryExecutor].
  NostrDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Upserts a profile row.
  Future<void> upsertProfile(ProfileTableCompanion entry) {
    return into(profileTable).insertOnConflictUpdate(entry);
  }

  /// Returns the profile for the given [pubkey], or `null`.
  Future<ProfileTableData?> getProfile(String pubkey) {
    return (select(
      profileTable,
    )..where((t) => t.pubkey.equals(pubkey))).getSingleOrNull();
  }

  /// Returns profiles for the given [pubkeys].
  Future<List<ProfileTableData>> getProfiles(List<String> pubkeys) {
    return (select(profileTable)..where((t) => t.pubkey.isIn(pubkeys))).get();
  }

  /// Deletes the profile for the given [pubkey].
  Future<int> deleteProfile(String pubkey) {
    return (delete(profileTable)..where((t) => t.pubkey.equals(pubkey))).go();
  }
}
