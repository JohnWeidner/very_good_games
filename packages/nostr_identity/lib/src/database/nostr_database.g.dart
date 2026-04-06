// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_database.dart';

// ignore_for_file: type=lint
class $ProfileTableTable extends ProfileTable
    with TableInfo<$ProfileTableTable, ProfileTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pictureMeta = const VerificationMeta(
    'picture',
  );
  @override
  late final GeneratedColumn<String> picture = GeneratedColumn<String>(
    'picture',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aboutMeta = const VerificationMeta('about');
  @override
  late final GeneratedColumn<String> about = GeneratedColumn<String>(
    'about',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFetchedAtMeta = const VerificationMeta(
    'lastFetchedAt',
  );
  @override
  late final GeneratedColumn<int> lastFetchedAt = GeneratedColumn<int>(
    'last_fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    name,
    picture,
    about,
    rawJson,
    createdAt,
    lastFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('picture')) {
      context.handle(
        _pictureMeta,
        picture.isAcceptableOrUnknown(data['picture']!, _pictureMeta),
      );
    }
    if (data.containsKey('about')) {
      context.handle(
        _aboutMeta,
        about.isAcceptableOrUnknown(data['about']!, _aboutMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_fetched_at')) {
      context.handle(
        _lastFetchedAtMeta,
        lastFetchedAt.isAcceptableOrUnknown(
          data['last_fetched_at']!,
          _lastFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  ProfileTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileTableData(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      picture: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}picture'],
      ),
      about: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}about'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      lastFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fetched_at'],
      ),
    );
  }

  @override
  $ProfileTableTable createAlias(String alias) {
    return $ProfileTableTable(attachedDatabase, alias);
  }
}

class ProfileTableData extends DataClass
    implements Insertable<ProfileTableData> {
  /// Hex-encoded public key (primary key).
  final String pubkey;

  /// Display name from kind-0 `name` field.
  final String? name;

  /// Profile picture URL from kind-0 `picture` field.
  final String? picture;

  /// Bio from kind-0 `about` field.
  final String? about;

  /// Full kind-0 content JSON, preserved for merge-on-write.
  final String? rawJson;

  /// Kind-0 event `created_at` (unix seconds).
  final int? createdAt;

  /// Local timestamp of last relay fetch (unix seconds).
  final int? lastFetchedAt;
  const ProfileTableData({
    required this.pubkey,
    this.name,
    this.picture,
    this.about,
    this.rawJson,
    this.createdAt,
    this.lastFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || picture != null) {
      map['picture'] = Variable<String>(picture);
    }
    if (!nullToAbsent || about != null) {
      map['about'] = Variable<String>(about);
    }
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || lastFetchedAt != null) {
      map['last_fetched_at'] = Variable<int>(lastFetchedAt);
    }
    return map;
  }

  ProfileTableCompanion toCompanion(bool nullToAbsent) {
    return ProfileTableCompanion(
      pubkey: Value(pubkey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      picture: picture == null && nullToAbsent
          ? const Value.absent()
          : Value(picture),
      about: about == null && nullToAbsent
          ? const Value.absent()
          : Value(about),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      lastFetchedAt: lastFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFetchedAt),
    );
  }

  factory ProfileTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileTableData(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      name: serializer.fromJson<String?>(json['name']),
      picture: serializer.fromJson<String?>(json['picture']),
      about: serializer.fromJson<String?>(json['about']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      lastFetchedAt: serializer.fromJson<int?>(json['lastFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'name': serializer.toJson<String?>(name),
      'picture': serializer.toJson<String?>(picture),
      'about': serializer.toJson<String?>(about),
      'rawJson': serializer.toJson<String?>(rawJson),
      'createdAt': serializer.toJson<int?>(createdAt),
      'lastFetchedAt': serializer.toJson<int?>(lastFetchedAt),
    };
  }

  ProfileTableData copyWith({
    String? pubkey,
    Value<String?> name = const Value.absent(),
    Value<String?> picture = const Value.absent(),
    Value<String?> about = const Value.absent(),
    Value<String?> rawJson = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    Value<int?> lastFetchedAt = const Value.absent(),
  }) => ProfileTableData(
    pubkey: pubkey ?? this.pubkey,
    name: name.present ? name.value : this.name,
    picture: picture.present ? picture.value : this.picture,
    about: about.present ? about.value : this.about,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    lastFetchedAt: lastFetchedAt.present
        ? lastFetchedAt.value
        : this.lastFetchedAt,
  );
  ProfileTableData copyWithCompanion(ProfileTableCompanion data) {
    return ProfileTableData(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      name: data.name.present ? data.name.value : this.name,
      picture: data.picture.present ? data.picture.value : this.picture,
      about: data.about.present ? data.about.value : this.about,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastFetchedAt: data.lastFetchedAt.present
          ? data.lastFetchedAt.value
          : this.lastFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileTableData(')
          ..write('pubkey: $pubkey, ')
          ..write('name: $name, ')
          ..write('picture: $picture, ')
          ..write('about: $about, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastFetchedAt: $lastFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    name,
    picture,
    about,
    rawJson,
    createdAt,
    lastFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileTableData &&
          other.pubkey == this.pubkey &&
          other.name == this.name &&
          other.picture == this.picture &&
          other.about == this.about &&
          other.rawJson == this.rawJson &&
          other.createdAt == this.createdAt &&
          other.lastFetchedAt == this.lastFetchedAt);
}

class ProfileTableCompanion extends UpdateCompanion<ProfileTableData> {
  final Value<String> pubkey;
  final Value<String?> name;
  final Value<String?> picture;
  final Value<String?> about;
  final Value<String?> rawJson;
  final Value<int?> createdAt;
  final Value<int?> lastFetchedAt;
  final Value<int> rowid;
  const ProfileTableCompanion({
    this.pubkey = const Value.absent(),
    this.name = const Value.absent(),
    this.picture = const Value.absent(),
    this.about = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfileTableCompanion.insert({
    required String pubkey,
    this.name = const Value.absent(),
    this.picture = const Value.absent(),
    this.about = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey);
  static Insertable<ProfileTableData> custom({
    Expression<String>? pubkey,
    Expression<String>? name,
    Expression<String>? picture,
    Expression<String>? about,
    Expression<String>? rawJson,
    Expression<int>? createdAt,
    Expression<int>? lastFetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (name != null) 'name': name,
      if (picture != null) 'picture': picture,
      if (about != null) 'about': about,
      if (rawJson != null) 'raw_json': rawJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastFetchedAt != null) 'last_fetched_at': lastFetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfileTableCompanion copyWith({
    Value<String>? pubkey,
    Value<String?>? name,
    Value<String?>? picture,
    Value<String?>? about,
    Value<String?>? rawJson,
    Value<int?>? createdAt,
    Value<int?>? lastFetchedAt,
    Value<int>? rowid,
  }) {
    return ProfileTableCompanion(
      pubkey: pubkey ?? this.pubkey,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      about: about ?? this.about,
      rawJson: rawJson ?? this.rawJson,
      createdAt: createdAt ?? this.createdAt,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (picture.present) {
      map['picture'] = Variable<String>(picture.value);
    }
    if (about.present) {
      map['about'] = Variable<String>(about.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastFetchedAt.present) {
      map['last_fetched_at'] = Variable<int>(lastFetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileTableCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('name: $name, ')
          ..write('picture: $picture, ')
          ..write('about: $about, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastFetchedAt: $lastFetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NostrDatabase extends GeneratedDatabase {
  _$NostrDatabase(QueryExecutor e) : super(e);
  $NostrDatabaseManager get managers => $NostrDatabaseManager(this);
  late final $ProfileTableTable profileTable = $ProfileTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [profileTable];
}

typedef $$ProfileTableTableCreateCompanionBuilder =
    ProfileTableCompanion Function({
      required String pubkey,
      Value<String?> name,
      Value<String?> picture,
      Value<String?> about,
      Value<String?> rawJson,
      Value<int?> createdAt,
      Value<int?> lastFetchedAt,
      Value<int> rowid,
    });
typedef $$ProfileTableTableUpdateCompanionBuilder =
    ProfileTableCompanion Function({
      Value<String> pubkey,
      Value<String?> name,
      Value<String?> picture,
      Value<String?> about,
      Value<String?> rawJson,
      Value<int?> createdAt,
      Value<int?> lastFetchedAt,
      Value<int> rowid,
    });

class $$ProfileTableTableFilterComposer
    extends Composer<_$NostrDatabase, $ProfileTableTable> {
  $$ProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get picture => $composableBuilder(
    column: $table.picture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableTableOrderingComposer
    extends Composer<_$NostrDatabase, $ProfileTableTable> {
  $$ProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get picture => $composableBuilder(
    column: $table.picture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableTableAnnotationComposer
    extends Composer<_$NostrDatabase, $ProfileTableTable> {
  $$ProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get picture =>
      $composableBuilder(column: $table.picture, builder: (column) => column);

  GeneratedColumn<String> get about =>
      $composableBuilder(column: $table.about, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => column,
  );
}

class $$ProfileTableTableTableManager
    extends
        RootTableManager<
          _$NostrDatabase,
          $ProfileTableTable,
          ProfileTableData,
          $$ProfileTableTableFilterComposer,
          $$ProfileTableTableOrderingComposer,
          $$ProfileTableTableAnnotationComposer,
          $$ProfileTableTableCreateCompanionBuilder,
          $$ProfileTableTableUpdateCompanionBuilder,
          (
            ProfileTableData,
            BaseReferences<
              _$NostrDatabase,
              $ProfileTableTable,
              ProfileTableData
            >,
          ),
          ProfileTableData,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableTableManager(_$NostrDatabase db, $ProfileTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> picture = const Value.absent(),
                Value<String?> about = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> lastFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfileTableCompanion(
                pubkey: pubkey,
                name: name,
                picture: picture,
                about: about,
                rawJson: rawJson,
                createdAt: createdAt,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                Value<String?> name = const Value.absent(),
                Value<String?> picture = const Value.absent(),
                Value<String?> about = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> lastFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfileTableCompanion.insert(
                pubkey: pubkey,
                name: name,
                picture: picture,
                about: about,
                rawJson: rawJson,
                createdAt: createdAt,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$NostrDatabase,
      $ProfileTableTable,
      ProfileTableData,
      $$ProfileTableTableFilterComposer,
      $$ProfileTableTableOrderingComposer,
      $$ProfileTableTableAnnotationComposer,
      $$ProfileTableTableCreateCompanionBuilder,
      $$ProfileTableTableUpdateCompanionBuilder,
      (
        ProfileTableData,
        BaseReferences<_$NostrDatabase, $ProfileTableTable, ProfileTableData>,
      ),
      ProfileTableData,
      PrefetchHooks Function()
    >;

class $NostrDatabaseManager {
  final _$NostrDatabase _db;
  $NostrDatabaseManager(this._db);
  $$ProfileTableTableTableManager get profileTable =>
      $$ProfileTableTableTableManager(_db, _db.profileTable);
}
