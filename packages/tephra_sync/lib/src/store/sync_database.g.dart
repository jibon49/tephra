// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_database.dart';

// ignore_for_file: type=lint
class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  /// Metadata setting key.
  final String key;

  /// String-encoded value (numbers formatted as decimal, JSON strings).
  final String value;
  const SyncMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaRow copyWith({String? key, String? value}) =>
      SyncMetaRow(key: key ?? this.key, value: value ?? this.value);
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncedFilesTable extends SyncedFiles
    with TableInfo<$SyncedFilesTable, SyncedFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseKeyMeta = const VerificationMeta(
    'caseKey',
  );
  @override
  late final GeneratedColumn<String> caseKey = GeneratedColumn<String>(
    'case_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobKeysMeta = const VerificationMeta(
    'blobKeys',
  );
  @override
  late final GeneratedColumn<String> blobKeys = GeneratedColumn<String>(
    'blob_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    caseKey,
    hash,
    size,
    mtime,
    version,
    blobKeys,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'synced_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncedFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('case_key')) {
      context.handle(
        _caseKeyMeta,
        caseKey.isAcceptableOrUnknown(data['case_key']!, _caseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_caseKeyMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('blob_keys')) {
      context.handle(
        _blobKeysMeta,
        blobKeys.isAcceptableOrUnknown(data['blob_keys']!, _blobKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_blobKeysMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  SyncedFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncedFileRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      caseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_key'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      blobKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_keys'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $SyncedFilesTable createAlias(String alias) {
    return $SyncedFilesTable(attachedDatabase, alias);
  }
}

class SyncedFileRow extends DataClass implements Insertable<SyncedFileRow> {
  /// Vault-relative path.
  final String path;

  /// Lower-case path for case-insensitive collision detection.
  final String caseKey;

  /// SHA-256 contentHash of the synced file content.
  final String hash;

  /// Size of the file in bytes.
  final int size;

  /// Modification time in milliseconds UTC.
  final int mtime;

  /// Remote entry id (`<deviceId>:<seq>`) that this file was last synced to.
  final String version;

  /// JSON list of remote blob keys composing this file's ciphertext.
  final String blobKeys;

  /// Sync timestamp in milliseconds UTC.
  final int syncedAt;
  const SyncedFileRow({
    required this.path,
    required this.caseKey,
    required this.hash,
    required this.size,
    required this.mtime,
    required this.version,
    required this.blobKeys,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['case_key'] = Variable<String>(caseKey);
    map['hash'] = Variable<String>(hash);
    map['size'] = Variable<int>(size);
    map['mtime'] = Variable<int>(mtime);
    map['version'] = Variable<String>(version);
    map['blob_keys'] = Variable<String>(blobKeys);
    map['synced_at'] = Variable<int>(syncedAt);
    return map;
  }

  SyncedFilesCompanion toCompanion(bool nullToAbsent) {
    return SyncedFilesCompanion(
      path: Value(path),
      caseKey: Value(caseKey),
      hash: Value(hash),
      size: Value(size),
      mtime: Value(mtime),
      version: Value(version),
      blobKeys: Value(blobKeys),
      syncedAt: Value(syncedAt),
    );
  }

  factory SyncedFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncedFileRow(
      path: serializer.fromJson<String>(json['path']),
      caseKey: serializer.fromJson<String>(json['caseKey']),
      hash: serializer.fromJson<String>(json['hash']),
      size: serializer.fromJson<int>(json['size']),
      mtime: serializer.fromJson<int>(json['mtime']),
      version: serializer.fromJson<String>(json['version']),
      blobKeys: serializer.fromJson<String>(json['blobKeys']),
      syncedAt: serializer.fromJson<int>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'caseKey': serializer.toJson<String>(caseKey),
      'hash': serializer.toJson<String>(hash),
      'size': serializer.toJson<int>(size),
      'mtime': serializer.toJson<int>(mtime),
      'version': serializer.toJson<String>(version),
      'blobKeys': serializer.toJson<String>(blobKeys),
      'syncedAt': serializer.toJson<int>(syncedAt),
    };
  }

  SyncedFileRow copyWith({
    String? path,
    String? caseKey,
    String? hash,
    int? size,
    int? mtime,
    String? version,
    String? blobKeys,
    int? syncedAt,
  }) => SyncedFileRow(
    path: path ?? this.path,
    caseKey: caseKey ?? this.caseKey,
    hash: hash ?? this.hash,
    size: size ?? this.size,
    mtime: mtime ?? this.mtime,
    version: version ?? this.version,
    blobKeys: blobKeys ?? this.blobKeys,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  SyncedFileRow copyWithCompanion(SyncedFilesCompanion data) {
    return SyncedFileRow(
      path: data.path.present ? data.path.value : this.path,
      caseKey: data.caseKey.present ? data.caseKey.value : this.caseKey,
      hash: data.hash.present ? data.hash.value : this.hash,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      version: data.version.present ? data.version.value : this.version,
      blobKeys: data.blobKeys.present ? data.blobKeys.value : this.blobKeys,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncedFileRow(')
          ..write('path: $path, ')
          ..write('caseKey: $caseKey, ')
          ..write('hash: $hash, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('version: $version, ')
          ..write('blobKeys: $blobKeys, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    caseKey,
    hash,
    size,
    mtime,
    version,
    blobKeys,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncedFileRow &&
          other.path == this.path &&
          other.caseKey == this.caseKey &&
          other.hash == this.hash &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.version == this.version &&
          other.blobKeys == this.blobKeys &&
          other.syncedAt == this.syncedAt);
}

class SyncedFilesCompanion extends UpdateCompanion<SyncedFileRow> {
  final Value<String> path;
  final Value<String> caseKey;
  final Value<String> hash;
  final Value<int> size;
  final Value<int> mtime;
  final Value<String> version;
  final Value<String> blobKeys;
  final Value<int> syncedAt;
  final Value<int> rowid;
  const SyncedFilesCompanion({
    this.path = const Value.absent(),
    this.caseKey = const Value.absent(),
    this.hash = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.version = const Value.absent(),
    this.blobKeys = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncedFilesCompanion.insert({
    required String path,
    required String caseKey,
    required String hash,
    required int size,
    required int mtime,
    required String version,
    required String blobKeys,
    required int syncedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       caseKey = Value(caseKey),
       hash = Value(hash),
       size = Value(size),
       mtime = Value(mtime),
       version = Value(version),
       blobKeys = Value(blobKeys),
       syncedAt = Value(syncedAt);
  static Insertable<SyncedFileRow> custom({
    Expression<String>? path,
    Expression<String>? caseKey,
    Expression<String>? hash,
    Expression<int>? size,
    Expression<int>? mtime,
    Expression<String>? version,
    Expression<String>? blobKeys,
    Expression<int>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (caseKey != null) 'case_key': caseKey,
      if (hash != null) 'hash': hash,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (version != null) 'version': version,
      if (blobKeys != null) 'blob_keys': blobKeys,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncedFilesCompanion copyWith({
    Value<String>? path,
    Value<String>? caseKey,
    Value<String>? hash,
    Value<int>? size,
    Value<int>? mtime,
    Value<String>? version,
    Value<String>? blobKeys,
    Value<int>? syncedAt,
    Value<int>? rowid,
  }) {
    return SyncedFilesCompanion(
      path: path ?? this.path,
      caseKey: caseKey ?? this.caseKey,
      hash: hash ?? this.hash,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      version: version ?? this.version,
      blobKeys: blobKeys ?? this.blobKeys,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (caseKey.present) {
      map['case_key'] = Variable<String>(caseKey.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (blobKeys.present) {
      map['blob_keys'] = Variable<String>(blobKeys.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncedFilesCompanion(')
          ..write('path: $path, ')
          ..write('caseKey: $caseKey, ')
          ..write('hash: $hash, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('version: $version, ')
          ..write('blobKeys: $blobKeys, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BasesTable extends Bases with TableInfo<$BasesTable, BaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textGzMeta = const VerificationMeta('textGz');
  @override
  late final GeneratedColumn<Uint8List> textGz = GeneratedColumn<Uint8List>(
    'text_gz',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, hash, textGz];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bases';
  @override
  VerificationContext validateIntegrity(
    Insertable<BaseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('text_gz')) {
      context.handle(
        _textGzMeta,
        textGz.isAcceptableOrUnknown(data['text_gz']!, _textGzMeta),
      );
    } else if (isInserting) {
      context.missing(_textGzMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  BaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BaseRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      textGz: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}text_gz'],
      )!,
    );
  }

  @override
  $BasesTable createAlias(String alias) {
    return $BasesTable(attachedDatabase, alias);
  }
}

class BaseRow extends DataClass implements Insertable<BaseRow> {
  /// Vault-relative path.
  final String path;

  /// Content hash matching [SyncedFiles.hash].
  final String hash;

  /// Gzip-compressed UTF-8 bytes of normalized newline text.
  final Uint8List textGz;
  const BaseRow({required this.path, required this.hash, required this.textGz});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['hash'] = Variable<String>(hash);
    map['text_gz'] = Variable<Uint8List>(textGz);
    return map;
  }

  BasesCompanion toCompanion(bool nullToAbsent) {
    return BasesCompanion(
      path: Value(path),
      hash: Value(hash),
      textGz: Value(textGz),
    );
  }

  factory BaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BaseRow(
      path: serializer.fromJson<String>(json['path']),
      hash: serializer.fromJson<String>(json['hash']),
      textGz: serializer.fromJson<Uint8List>(json['textGz']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'hash': serializer.toJson<String>(hash),
      'textGz': serializer.toJson<Uint8List>(textGz),
    };
  }

  BaseRow copyWith({String? path, String? hash, Uint8List? textGz}) => BaseRow(
    path: path ?? this.path,
    hash: hash ?? this.hash,
    textGz: textGz ?? this.textGz,
  );
  BaseRow copyWithCompanion(BasesCompanion data) {
    return BaseRow(
      path: data.path.present ? data.path.value : this.path,
      hash: data.hash.present ? data.hash.value : this.hash,
      textGz: data.textGz.present ? data.textGz.value : this.textGz,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BaseRow(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('textGz: $textGz')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, hash, $driftBlobEquality.hash(textGz));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BaseRow &&
          other.path == this.path &&
          other.hash == this.hash &&
          $driftBlobEquality.equals(other.textGz, this.textGz));
}

class BasesCompanion extends UpdateCompanion<BaseRow> {
  final Value<String> path;
  final Value<String> hash;
  final Value<Uint8List> textGz;
  final Value<int> rowid;
  const BasesCompanion({
    this.path = const Value.absent(),
    this.hash = const Value.absent(),
    this.textGz = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BasesCompanion.insert({
    required String path,
    required String hash,
    required Uint8List textGz,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       hash = Value(hash),
       textGz = Value(textGz);
  static Insertable<BaseRow> custom({
    Expression<String>? path,
    Expression<String>? hash,
    Expression<Uint8List>? textGz,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (hash != null) 'hash': hash,
      if (textGz != null) 'text_gz': textGz,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BasesCompanion copyWith({
    Value<String>? path,
    Value<String>? hash,
    Value<Uint8List>? textGz,
    Value<int>? rowid,
  }) {
    return BasesCompanion(
      path: path ?? this.path,
      hash: hash ?? this.hash,
      textGz: textGz ?? this.textGz,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (textGz.present) {
      map['text_gz'] = Variable<Uint8List>(textGz.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BasesCompanion(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('textGz: $textGz, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalHashCacheTable extends LocalHashCache
    with TableInfo<$LocalHashCacheTable, LocalHashCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalHashCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, size, mtime, hash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_hash_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHashCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LocalHashCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHashCacheRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
    );
  }

  @override
  $LocalHashCacheTable createAlias(String alias) {
    return $LocalHashCacheTable(attachedDatabase, alias);
  }
}

class LocalHashCacheRow extends DataClass
    implements Insertable<LocalHashCacheRow> {
  /// Vault-relative path.
  final String path;

  /// File size in bytes.
  final int size;

  /// Last modification time in milliseconds UTC.
  final int mtime;

  /// SHA-256 hash.
  final String hash;
  const LocalHashCacheRow({
    required this.path,
    required this.size,
    required this.mtime,
    required this.hash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['size'] = Variable<int>(size);
    map['mtime'] = Variable<int>(mtime);
    map['hash'] = Variable<String>(hash);
    return map;
  }

  LocalHashCacheCompanion toCompanion(bool nullToAbsent) {
    return LocalHashCacheCompanion(
      path: Value(path),
      size: Value(size),
      mtime: Value(mtime),
      hash: Value(hash),
    );
  }

  factory LocalHashCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHashCacheRow(
      path: serializer.fromJson<String>(json['path']),
      size: serializer.fromJson<int>(json['size']),
      mtime: serializer.fromJson<int>(json['mtime']),
      hash: serializer.fromJson<String>(json['hash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'size': serializer.toJson<int>(size),
      'mtime': serializer.toJson<int>(mtime),
      'hash': serializer.toJson<String>(hash),
    };
  }

  LocalHashCacheRow copyWith({
    String? path,
    int? size,
    int? mtime,
    String? hash,
  }) => LocalHashCacheRow(
    path: path ?? this.path,
    size: size ?? this.size,
    mtime: mtime ?? this.mtime,
    hash: hash ?? this.hash,
  );
  LocalHashCacheRow copyWithCompanion(LocalHashCacheCompanion data) {
    return LocalHashCacheRow(
      path: data.path.present ? data.path.value : this.path,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      hash: data.hash.present ? data.hash.value : this.hash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHashCacheRow(')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('hash: $hash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, size, mtime, hash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHashCacheRow &&
          other.path == this.path &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.hash == this.hash);
}

class LocalHashCacheCompanion extends UpdateCompanion<LocalHashCacheRow> {
  final Value<String> path;
  final Value<int> size;
  final Value<int> mtime;
  final Value<String> hash;
  final Value<int> rowid;
  const LocalHashCacheCompanion({
    this.path = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalHashCacheCompanion.insert({
    required String path,
    required int size,
    required int mtime,
    required String hash,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       size = Value(size),
       mtime = Value(mtime),
       hash = Value(hash);
  static Insertable<LocalHashCacheRow> custom({
    Expression<String>? path,
    Expression<int>? size,
    Expression<int>? mtime,
    Expression<String>? hash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (hash != null) 'hash': hash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalHashCacheCompanion copyWith({
    Value<String>? path,
    Value<int>? size,
    Value<int>? mtime,
    Value<String>? hash,
    Value<int>? rowid,
  }) {
    return LocalHashCacheCompanion(
      path: path ?? this.path,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      hash: hash ?? this.hash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalHashCacheCompanion(')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('hash: $hash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemoteEntriesTable extends RemoteEntries
    with TableInfo<$RemoteEntriesTable, RemoteEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromPathMeta = const VerificationMeta(
    'fromPath',
  );
  @override
  late final GeneratedColumn<String> fromPath = GeneratedColumn<String>(
    'from_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blobKeysMeta = const VerificationMeta(
    'blobKeys',
  );
  @override
  late final GeneratedColumn<String> blobKeys = GeneratedColumn<String>(
    'blob_keys',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentMeta = const VerificationMeta('parent');
  @override
  late final GeneratedColumn<String> parent = GeneratedColumn<String>(
    'parent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetParentMeta = const VerificationMeta(
    'targetParent',
  );
  @override
  late final GeneratedColumn<String> targetParent = GeneratedColumn<String>(
    'target_parent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mergedParentMeta = const VerificationMeta(
    'mergedParent',
  );
  @override
  late final GeneratedColumn<String> mergedParent = GeneratedColumn<String>(
    'merged_parent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    deviceId,
    seq,
    hlc,
    op,
    path,
    fromPath,
    hash,
    size,
    mtime,
    blobKeys,
    parent,
    targetParent,
    mergedParent,
    time,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('from_path')) {
      context.handle(
        _fromPathMeta,
        fromPath.isAcceptableOrUnknown(data['from_path']!, _fromPathMeta),
      );
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    }
    if (data.containsKey('blob_keys')) {
      context.handle(
        _blobKeysMeta,
        blobKeys.isAcceptableOrUnknown(data['blob_keys']!, _blobKeysMeta),
      );
    }
    if (data.containsKey('parent')) {
      context.handle(
        _parentMeta,
        parent.isAcceptableOrUnknown(data['parent']!, _parentMeta),
      );
    }
    if (data.containsKey('target_parent')) {
      context.handle(
        _targetParentMeta,
        targetParent.isAcceptableOrUnknown(
          data['target_parent']!,
          _targetParentMeta,
        ),
      );
    }
    if (data.containsKey('merged_parent')) {
      context.handle(
        _mergedParentMeta,
        mergedParent.isAcceptableOrUnknown(
          data['merged_parent']!,
          _mergedParentMeta,
        ),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  RemoteEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteEntryRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fromPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_path'],
      ),
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      ),
      blobKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_keys'],
      ),
      parent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent'],
      ),
      targetParent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_parent'],
      ),
      mergedParent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merged_parent'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
    );
  }

  @override
  $RemoteEntriesTable createAlias(String alias) {
    return $RemoteEntriesTable(attachedDatabase, alias);
  }
}

class RemoteEntryRow extends DataClass implements Insertable<RemoteEntryRow> {
  /// Unique entry id (`<deviceId>:<seq>`).
  final String entryId;

  /// Originating device UUID.
  final String deviceId;

  /// Sequence number on the originating device.
  final int seq;

  /// Hybrid Logical Clock timestamp string.
  final String hlc;

  /// Operation kind (`put`, `delete`, `move`).
  final String op;

  /// Target vault-relative path.
  final String path;

  /// Source path if op is `move`.
  final String? fromPath;

  /// Content hash for put operations.
  final String? hash;

  /// File size in bytes.
  final int? size;

  /// Modification time in milliseconds UTC.
  final int? mtime;

  /// JSON list of remote blob keys.
  final String? blobKeys;

  /// Parent entry id for single-parent edits.
  final String? parent;

  /// Target path parent entry id for moves.
  final String? targetParent;

  /// Second parent entry id if this entry was created by a merge.
  final String? mergedParent;

  /// Creation time in milliseconds UTC.
  final int time;
  const RemoteEntryRow({
    required this.entryId,
    required this.deviceId,
    required this.seq,
    required this.hlc,
    required this.op,
    required this.path,
    this.fromPath,
    this.hash,
    this.size,
    this.mtime,
    this.blobKeys,
    this.parent,
    this.targetParent,
    this.mergedParent,
    required this.time,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['device_id'] = Variable<String>(deviceId);
    map['seq'] = Variable<int>(seq);
    map['hlc'] = Variable<String>(hlc);
    map['op'] = Variable<String>(op);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || fromPath != null) {
      map['from_path'] = Variable<String>(fromPath);
    }
    if (!nullToAbsent || hash != null) {
      map['hash'] = Variable<String>(hash);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || mtime != null) {
      map['mtime'] = Variable<int>(mtime);
    }
    if (!nullToAbsent || blobKeys != null) {
      map['blob_keys'] = Variable<String>(blobKeys);
    }
    if (!nullToAbsent || parent != null) {
      map['parent'] = Variable<String>(parent);
    }
    if (!nullToAbsent || targetParent != null) {
      map['target_parent'] = Variable<String>(targetParent);
    }
    if (!nullToAbsent || mergedParent != null) {
      map['merged_parent'] = Variable<String>(mergedParent);
    }
    map['time'] = Variable<int>(time);
    return map;
  }

  RemoteEntriesCompanion toCompanion(bool nullToAbsent) {
    return RemoteEntriesCompanion(
      entryId: Value(entryId),
      deviceId: Value(deviceId),
      seq: Value(seq),
      hlc: Value(hlc),
      op: Value(op),
      path: Value(path),
      fromPath: fromPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fromPath),
      hash: hash == null && nullToAbsent ? const Value.absent() : Value(hash),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      mtime: mtime == null && nullToAbsent
          ? const Value.absent()
          : Value(mtime),
      blobKeys: blobKeys == null && nullToAbsent
          ? const Value.absent()
          : Value(blobKeys),
      parent: parent == null && nullToAbsent
          ? const Value.absent()
          : Value(parent),
      targetParent: targetParent == null && nullToAbsent
          ? const Value.absent()
          : Value(targetParent),
      mergedParent: mergedParent == null && nullToAbsent
          ? const Value.absent()
          : Value(mergedParent),
      time: Value(time),
    );
  }

  factory RemoteEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteEntryRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      seq: serializer.fromJson<int>(json['seq']),
      hlc: serializer.fromJson<String>(json['hlc']),
      op: serializer.fromJson<String>(json['op']),
      path: serializer.fromJson<String>(json['path']),
      fromPath: serializer.fromJson<String?>(json['fromPath']),
      hash: serializer.fromJson<String?>(json['hash']),
      size: serializer.fromJson<int?>(json['size']),
      mtime: serializer.fromJson<int?>(json['mtime']),
      blobKeys: serializer.fromJson<String?>(json['blobKeys']),
      parent: serializer.fromJson<String?>(json['parent']),
      targetParent: serializer.fromJson<String?>(json['targetParent']),
      mergedParent: serializer.fromJson<String?>(json['mergedParent']),
      time: serializer.fromJson<int>(json['time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'deviceId': serializer.toJson<String>(deviceId),
      'seq': serializer.toJson<int>(seq),
      'hlc': serializer.toJson<String>(hlc),
      'op': serializer.toJson<String>(op),
      'path': serializer.toJson<String>(path),
      'fromPath': serializer.toJson<String?>(fromPath),
      'hash': serializer.toJson<String?>(hash),
      'size': serializer.toJson<int?>(size),
      'mtime': serializer.toJson<int?>(mtime),
      'blobKeys': serializer.toJson<String?>(blobKeys),
      'parent': serializer.toJson<String?>(parent),
      'targetParent': serializer.toJson<String?>(targetParent),
      'mergedParent': serializer.toJson<String?>(mergedParent),
      'time': serializer.toJson<int>(time),
    };
  }

  RemoteEntryRow copyWith({
    String? entryId,
    String? deviceId,
    int? seq,
    String? hlc,
    String? op,
    String? path,
    Value<String?> fromPath = const Value.absent(),
    Value<String?> hash = const Value.absent(),
    Value<int?> size = const Value.absent(),
    Value<int?> mtime = const Value.absent(),
    Value<String?> blobKeys = const Value.absent(),
    Value<String?> parent = const Value.absent(),
    Value<String?> targetParent = const Value.absent(),
    Value<String?> mergedParent = const Value.absent(),
    int? time,
  }) => RemoteEntryRow(
    entryId: entryId ?? this.entryId,
    deviceId: deviceId ?? this.deviceId,
    seq: seq ?? this.seq,
    hlc: hlc ?? this.hlc,
    op: op ?? this.op,
    path: path ?? this.path,
    fromPath: fromPath.present ? fromPath.value : this.fromPath,
    hash: hash.present ? hash.value : this.hash,
    size: size.present ? size.value : this.size,
    mtime: mtime.present ? mtime.value : this.mtime,
    blobKeys: blobKeys.present ? blobKeys.value : this.blobKeys,
    parent: parent.present ? parent.value : this.parent,
    targetParent: targetParent.present ? targetParent.value : this.targetParent,
    mergedParent: mergedParent.present ? mergedParent.value : this.mergedParent,
    time: time ?? this.time,
  );
  RemoteEntryRow copyWithCompanion(RemoteEntriesCompanion data) {
    return RemoteEntryRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      seq: data.seq.present ? data.seq.value : this.seq,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      op: data.op.present ? data.op.value : this.op,
      path: data.path.present ? data.path.value : this.path,
      fromPath: data.fromPath.present ? data.fromPath.value : this.fromPath,
      hash: data.hash.present ? data.hash.value : this.hash,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      blobKeys: data.blobKeys.present ? data.blobKeys.value : this.blobKeys,
      parent: data.parent.present ? data.parent.value : this.parent,
      targetParent: data.targetParent.present
          ? data.targetParent.value
          : this.targetParent,
      mergedParent: data.mergedParent.present
          ? data.mergedParent.value
          : this.mergedParent,
      time: data.time.present ? data.time.value : this.time,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteEntryRow(')
          ..write('entryId: $entryId, ')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq, ')
          ..write('hlc: $hlc, ')
          ..write('op: $op, ')
          ..write('path: $path, ')
          ..write('fromPath: $fromPath, ')
          ..write('hash: $hash, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('blobKeys: $blobKeys, ')
          ..write('parent: $parent, ')
          ..write('targetParent: $targetParent, ')
          ..write('mergedParent: $mergedParent, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    deviceId,
    seq,
    hlc,
    op,
    path,
    fromPath,
    hash,
    size,
    mtime,
    blobKeys,
    parent,
    targetParent,
    mergedParent,
    time,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteEntryRow &&
          other.entryId == this.entryId &&
          other.deviceId == this.deviceId &&
          other.seq == this.seq &&
          other.hlc == this.hlc &&
          other.op == this.op &&
          other.path == this.path &&
          other.fromPath == this.fromPath &&
          other.hash == this.hash &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.blobKeys == this.blobKeys &&
          other.parent == this.parent &&
          other.targetParent == this.targetParent &&
          other.mergedParent == this.mergedParent &&
          other.time == this.time);
}

class RemoteEntriesCompanion extends UpdateCompanion<RemoteEntryRow> {
  final Value<String> entryId;
  final Value<String> deviceId;
  final Value<int> seq;
  final Value<String> hlc;
  final Value<String> op;
  final Value<String> path;
  final Value<String?> fromPath;
  final Value<String?> hash;
  final Value<int?> size;
  final Value<int?> mtime;
  final Value<String?> blobKeys;
  final Value<String?> parent;
  final Value<String?> targetParent;
  final Value<String?> mergedParent;
  final Value<int> time;
  final Value<int> rowid;
  const RemoteEntriesCompanion({
    this.entryId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.seq = const Value.absent(),
    this.hlc = const Value.absent(),
    this.op = const Value.absent(),
    this.path = const Value.absent(),
    this.fromPath = const Value.absent(),
    this.hash = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.blobKeys = const Value.absent(),
    this.parent = const Value.absent(),
    this.targetParent = const Value.absent(),
    this.mergedParent = const Value.absent(),
    this.time = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteEntriesCompanion.insert({
    required String entryId,
    required String deviceId,
    required int seq,
    required String hlc,
    required String op,
    required String path,
    this.fromPath = const Value.absent(),
    this.hash = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.blobKeys = const Value.absent(),
    this.parent = const Value.absent(),
    this.targetParent = const Value.absent(),
    this.mergedParent = const Value.absent(),
    required int time,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       deviceId = Value(deviceId),
       seq = Value(seq),
       hlc = Value(hlc),
       op = Value(op),
       path = Value(path),
       time = Value(time);
  static Insertable<RemoteEntryRow> custom({
    Expression<String>? entryId,
    Expression<String>? deviceId,
    Expression<int>? seq,
    Expression<String>? hlc,
    Expression<String>? op,
    Expression<String>? path,
    Expression<String>? fromPath,
    Expression<String>? hash,
    Expression<int>? size,
    Expression<int>? mtime,
    Expression<String>? blobKeys,
    Expression<String>? parent,
    Expression<String>? targetParent,
    Expression<String>? mergedParent,
    Expression<int>? time,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (deviceId != null) 'device_id': deviceId,
      if (seq != null) 'seq': seq,
      if (hlc != null) 'hlc': hlc,
      if (op != null) 'op': op,
      if (path != null) 'path': path,
      if (fromPath != null) 'from_path': fromPath,
      if (hash != null) 'hash': hash,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (blobKeys != null) 'blob_keys': blobKeys,
      if (parent != null) 'parent': parent,
      if (targetParent != null) 'target_parent': targetParent,
      if (mergedParent != null) 'merged_parent': mergedParent,
      if (time != null) 'time': time,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteEntriesCompanion copyWith({
    Value<String>? entryId,
    Value<String>? deviceId,
    Value<int>? seq,
    Value<String>? hlc,
    Value<String>? op,
    Value<String>? path,
    Value<String?>? fromPath,
    Value<String?>? hash,
    Value<int?>? size,
    Value<int?>? mtime,
    Value<String?>? blobKeys,
    Value<String?>? parent,
    Value<String?>? targetParent,
    Value<String?>? mergedParent,
    Value<int>? time,
    Value<int>? rowid,
  }) {
    return RemoteEntriesCompanion(
      entryId: entryId ?? this.entryId,
      deviceId: deviceId ?? this.deviceId,
      seq: seq ?? this.seq,
      hlc: hlc ?? this.hlc,
      op: op ?? this.op,
      path: path ?? this.path,
      fromPath: fromPath ?? this.fromPath,
      hash: hash ?? this.hash,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      blobKeys: blobKeys ?? this.blobKeys,
      parent: parent ?? this.parent,
      targetParent: targetParent ?? this.targetParent,
      mergedParent: mergedParent ?? this.mergedParent,
      time: time ?? this.time,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fromPath.present) {
      map['from_path'] = Variable<String>(fromPath.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (blobKeys.present) {
      map['blob_keys'] = Variable<String>(blobKeys.value);
    }
    if (parent.present) {
      map['parent'] = Variable<String>(parent.value);
    }
    if (targetParent.present) {
      map['target_parent'] = Variable<String>(targetParent.value);
    }
    if (mergedParent.present) {
      map['merged_parent'] = Variable<String>(mergedParent.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteEntriesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq, ')
          ..write('hlc: $hlc, ')
          ..write('op: $op, ')
          ..write('path: $path, ')
          ..write('fromPath: $fromPath, ')
          ..write('hash: $hash, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('blobKeys: $blobKeys, ')
          ..write('parent: $parent, ')
          ..write('targetParent: $targetParent, ')
          ..write('mergedParent: $mergedParent, ')
          ..write('time: $time, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemoteHeadsTable extends RemoteHeads
    with TableInfo<$RemoteHeadsTable, RemoteHeadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteHeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isForkMeta = const VerificationMeta('isFork');
  @override
  late final GeneratedColumn<int> isFork = GeneratedColumn<int>(
    'is_fork',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, entryId, isFork];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_heads';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteHeadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('is_fork')) {
      context.handle(
        _isForkMeta,
        isFork.isAcceptableOrUnknown(data['is_fork']!, _isForkMeta),
      );
    } else if (isInserting) {
      context.missing(_isForkMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  RemoteHeadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteHeadRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      isFork: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_fork'],
      )!,
    );
  }

  @override
  $RemoteHeadsTable createAlias(String alias) {
    return $RemoteHeadsTable(attachedDatabase, alias);
  }
}

class RemoteHeadRow extends DataClass implements Insertable<RemoteHeadRow> {
  /// Vault-relative path.
  final String path;

  /// Current head entry id.
  final String entryId;

  /// 1 if this path has concurrent unmerged leaves (fork), 0 otherwise.
  final int isFork;
  const RemoteHeadRow({
    required this.path,
    required this.entryId,
    required this.isFork,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['entry_id'] = Variable<String>(entryId);
    map['is_fork'] = Variable<int>(isFork);
    return map;
  }

  RemoteHeadsCompanion toCompanion(bool nullToAbsent) {
    return RemoteHeadsCompanion(
      path: Value(path),
      entryId: Value(entryId),
      isFork: Value(isFork),
    );
  }

  factory RemoteHeadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteHeadRow(
      path: serializer.fromJson<String>(json['path']),
      entryId: serializer.fromJson<String>(json['entryId']),
      isFork: serializer.fromJson<int>(json['isFork']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'entryId': serializer.toJson<String>(entryId),
      'isFork': serializer.toJson<int>(isFork),
    };
  }

  RemoteHeadRow copyWith({String? path, String? entryId, int? isFork}) =>
      RemoteHeadRow(
        path: path ?? this.path,
        entryId: entryId ?? this.entryId,
        isFork: isFork ?? this.isFork,
      );
  RemoteHeadRow copyWithCompanion(RemoteHeadsCompanion data) {
    return RemoteHeadRow(
      path: data.path.present ? data.path.value : this.path,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      isFork: data.isFork.present ? data.isFork.value : this.isFork,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteHeadRow(')
          ..write('path: $path, ')
          ..write('entryId: $entryId, ')
          ..write('isFork: $isFork')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, entryId, isFork);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteHeadRow &&
          other.path == this.path &&
          other.entryId == this.entryId &&
          other.isFork == this.isFork);
}

class RemoteHeadsCompanion extends UpdateCompanion<RemoteHeadRow> {
  final Value<String> path;
  final Value<String> entryId;
  final Value<int> isFork;
  final Value<int> rowid;
  const RemoteHeadsCompanion({
    this.path = const Value.absent(),
    this.entryId = const Value.absent(),
    this.isFork = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteHeadsCompanion.insert({
    required String path,
    required String entryId,
    required int isFork,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       entryId = Value(entryId),
       isFork = Value(isFork);
  static Insertable<RemoteHeadRow> custom({
    Expression<String>? path,
    Expression<String>? entryId,
    Expression<int>? isFork,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (entryId != null) 'entry_id': entryId,
      if (isFork != null) 'is_fork': isFork,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteHeadsCompanion copyWith({
    Value<String>? path,
    Value<String>? entryId,
    Value<int>? isFork,
    Value<int>? rowid,
  }) {
    return RemoteHeadsCompanion(
      path: path ?? this.path,
      entryId: entryId ?? this.entryId,
      isFork: isFork ?? this.isFork,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (isFork.present) {
      map['is_fork'] = Variable<int>(isFork.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteHeadsCompanion(')
          ..write('path: $path, ')
          ..write('entryId: $entryId, ')
          ..write('isFork: $isFork, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalCursorsTable extends JournalCursors
    with TableInfo<$JournalCursorsTable, JournalCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeqMeta = const VerificationMeta(
    'lastSeq',
  );
  @override
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
    'last_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revokedAfterSeqMeta = const VerificationMeta(
    'revokedAfterSeq',
  );
  @override
  late final GeneratedColumn<int> revokedAfterSeq = GeneratedColumn<int>(
    'revoked_after_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    lastSeq,
    deviceName,
    platform,
    lastSeenAt,
    revokedAfterSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('last_seq')) {
      context.handle(
        _lastSeqMeta,
        lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeqMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('revoked_after_seq')) {
      context.handle(
        _revokedAfterSeqMeta,
        revokedAfterSeq.isAcceptableOrUnknown(
          data['revoked_after_seq']!,
          _revokedAfterSeqMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  JournalCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalCursorRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      lastSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seq'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      ),
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      ),
      revokedAfterSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revoked_after_seq'],
      ),
    );
  }

  @override
  $JournalCursorsTable createAlias(String alias) {
    return $JournalCursorsTable(attachedDatabase, alias);
  }
}

class JournalCursorRow extends DataClass
    implements Insertable<JournalCursorRow> {
  /// Device UUID.
  final String deviceId;

  /// Last journal sequence processed from this device.
  final int lastSeq;

  /// Human-readable device name.
  final String? deviceName;

  /// Device platform ('android' or 'windows').
  final String? platform;

  /// Last seen timestamp in milliseconds UTC.
  final int? lastSeenAt;

  /// If revoked, journals after this sequence are ignored.
  final int? revokedAfterSeq;
  const JournalCursorRow({
    required this.deviceId,
    required this.lastSeq,
    this.deviceName,
    this.platform,
    this.lastSeenAt,
    this.revokedAfterSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['last_seq'] = Variable<int>(lastSeq);
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    if (!nullToAbsent || revokedAfterSeq != null) {
      map['revoked_after_seq'] = Variable<int>(revokedAfterSeq);
    }
    return map;
  }

  JournalCursorsCompanion toCompanion(bool nullToAbsent) {
    return JournalCursorsCompanion(
      deviceId: Value(deviceId),
      lastSeq: Value(lastSeq),
      deviceName: deviceName == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceName),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      revokedAfterSeq: revokedAfterSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(revokedAfterSeq),
    );
  }

  factory JournalCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalCursorRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      lastSeq: serializer.fromJson<int>(json['lastSeq']),
      deviceName: serializer.fromJson<String?>(json['deviceName']),
      platform: serializer.fromJson<String?>(json['platform']),
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      revokedAfterSeq: serializer.fromJson<int?>(json['revokedAfterSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'lastSeq': serializer.toJson<int>(lastSeq),
      'deviceName': serializer.toJson<String?>(deviceName),
      'platform': serializer.toJson<String?>(platform),
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'revokedAfterSeq': serializer.toJson<int?>(revokedAfterSeq),
    };
  }

  JournalCursorRow copyWith({
    String? deviceId,
    int? lastSeq,
    Value<String?> deviceName = const Value.absent(),
    Value<String?> platform = const Value.absent(),
    Value<int?> lastSeenAt = const Value.absent(),
    Value<int?> revokedAfterSeq = const Value.absent(),
  }) => JournalCursorRow(
    deviceId: deviceId ?? this.deviceId,
    lastSeq: lastSeq ?? this.lastSeq,
    deviceName: deviceName.present ? deviceName.value : this.deviceName,
    platform: platform.present ? platform.value : this.platform,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    revokedAfterSeq: revokedAfterSeq.present
        ? revokedAfterSeq.value
        : this.revokedAfterSeq,
  );
  JournalCursorRow copyWithCompanion(JournalCursorsCompanion data) {
    return JournalCursorRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      platform: data.platform.present ? data.platform.value : this.platform,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      revokedAfterSeq: data.revokedAfterSeq.present
          ? data.revokedAfterSeq.value
          : this.revokedAfterSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalCursorRow(')
          ..write('deviceId: $deviceId, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('deviceName: $deviceName, ')
          ..write('platform: $platform, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('revokedAfterSeq: $revokedAfterSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    lastSeq,
    deviceName,
    platform,
    lastSeenAt,
    revokedAfterSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalCursorRow &&
          other.deviceId == this.deviceId &&
          other.lastSeq == this.lastSeq &&
          other.deviceName == this.deviceName &&
          other.platform == this.platform &&
          other.lastSeenAt == this.lastSeenAt &&
          other.revokedAfterSeq == this.revokedAfterSeq);
}

class JournalCursorsCompanion extends UpdateCompanion<JournalCursorRow> {
  final Value<String> deviceId;
  final Value<int> lastSeq;
  final Value<String?> deviceName;
  final Value<String?> platform;
  final Value<int?> lastSeenAt;
  final Value<int?> revokedAfterSeq;
  final Value<int> rowid;
  const JournalCursorsCompanion({
    this.deviceId = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.platform = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.revokedAfterSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalCursorsCompanion.insert({
    required String deviceId,
    required int lastSeq,
    this.deviceName = const Value.absent(),
    this.platform = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.revokedAfterSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       lastSeq = Value(lastSeq);
  static Insertable<JournalCursorRow> custom({
    Expression<String>? deviceId,
    Expression<int>? lastSeq,
    Expression<String>? deviceName,
    Expression<String>? platform,
    Expression<int>? lastSeenAt,
    Expression<int>? revokedAfterSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (deviceName != null) 'device_name': deviceName,
      if (platform != null) 'platform': platform,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (revokedAfterSeq != null) 'revoked_after_seq': revokedAfterSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalCursorsCompanion copyWith({
    Value<String>? deviceId,
    Value<int>? lastSeq,
    Value<String?>? deviceName,
    Value<String?>? platform,
    Value<int?>? lastSeenAt,
    Value<int?>? revokedAfterSeq,
    Value<int>? rowid,
  }) {
    return JournalCursorsCompanion(
      deviceId: deviceId ?? this.deviceId,
      lastSeq: lastSeq ?? this.lastSeq,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      revokedAfterSeq: revokedAfterSeq ?? this.revokedAfterSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (revokedAfterSeq.present) {
      map['revoked_after_seq'] = Variable<int>(revokedAfterSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalCursorsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('deviceName: $deviceName, ')
          ..write('platform: $platform, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('revokedAfterSeq: $revokedAfterSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOpsTable extends PendingOps
    with TableInfo<$PendingOpsTable, PendingOpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    payload,
    state,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptsMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOpRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingOpsTable createAlias(String alias) {
    return $PendingOpsTable(attachedDatabase, alias);
  }
}

class PendingOpRow extends DataClass implements Insertable<PendingOpRow> {
  /// Unique auto-incrementing ID.
  final int id;

  /// Operation kind ('uploadJournal', 'heldDelete', etc.).
  final String kind;

  /// JSON payload describing the operation parameters.
  final String payload;

  /// Operation state ('pending', 'running', 'failed').
  final String state;

  /// Timestamp created in milliseconds UTC.
  final int createdAt;

  /// Number of retry attempts made.
  final int attempts;

  /// Last failure error message.
  final String? lastError;
  const PendingOpRow({
    required this.id,
    required this.kind,
    required this.payload,
    required this.state,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<int>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingOpsCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      state: Value(state),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingOpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOpRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<int>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingOpRow copyWith({
    int? id,
    String? kind,
    String? payload,
    String? state,
    int? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => PendingOpRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingOpRow copyWithCompanion(PendingOpsCompanion data) {
    return PendingOpRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, payload, state, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOpRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOpRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<String> state;
  final Value<int> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PendingOpsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String payload,
    required String state,
    required int createdAt,
    required int attempts,
    this.lastError = const Value.absent(),
  }) : kind = Value(kind),
       payload = Value(payload),
       state = Value(state),
       createdAt = Value(createdAt),
       attempts = Value(attempts);
  static Insertable<PendingOpRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<int>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? payload,
    Value<String>? state,
    Value<int>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return PendingOpsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $RemoteFileIdsTable extends RemoteFileIds
    with TableInfo<$RemoteFileIdsTable, RemoteFileIdRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteFileIdsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [key, fileId, size, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_file_ids';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteFileIdRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RemoteFileIdRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteFileIdRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $RemoteFileIdsTable createAlias(String alias) {
    return $RemoteFileIdsTable(attachedDatabase, alias);
  }
}

class RemoteFileIdRow extends DataClass implements Insertable<RemoteFileIdRow> {
  /// Remote object key (e.g. `blobs/...`, `vault.json`).
  final String key;

  /// Google Drive file ID.
  final String fileId;

  /// Object size in bytes.
  final int? size;

  /// Object creation time in milliseconds UTC.
  final int? createdAt;
  const RemoteFileIdRow({
    required this.key,
    required this.fileId,
    this.size,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['file_id'] = Variable<String>(fileId);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    return map;
  }

  RemoteFileIdsCompanion toCompanion(bool nullToAbsent) {
    return RemoteFileIdsCompanion(
      key: Value(key),
      fileId: Value(fileId),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory RemoteFileIdRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteFileIdRow(
      key: serializer.fromJson<String>(json['key']),
      fileId: serializer.fromJson<String>(json['fileId']),
      size: serializer.fromJson<int?>(json['size']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'fileId': serializer.toJson<String>(fileId),
      'size': serializer.toJson<int?>(size),
      'createdAt': serializer.toJson<int?>(createdAt),
    };
  }

  RemoteFileIdRow copyWith({
    String? key,
    String? fileId,
    Value<int?> size = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
  }) => RemoteFileIdRow(
    key: key ?? this.key,
    fileId: fileId ?? this.fileId,
    size: size.present ? size.value : this.size,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  RemoteFileIdRow copyWithCompanion(RemoteFileIdsCompanion data) {
    return RemoteFileIdRow(
      key: data.key.present ? data.key.value : this.key,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      size: data.size.present ? data.size.value : this.size,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteFileIdRow(')
          ..write('key: $key, ')
          ..write('fileId: $fileId, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, fileId, size, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteFileIdRow &&
          other.key == this.key &&
          other.fileId == this.fileId &&
          other.size == this.size &&
          other.createdAt == this.createdAt);
}

class RemoteFileIdsCompanion extends UpdateCompanion<RemoteFileIdRow> {
  final Value<String> key;
  final Value<String> fileId;
  final Value<int?> size;
  final Value<int?> createdAt;
  final Value<int> rowid;
  const RemoteFileIdsCompanion({
    this.key = const Value.absent(),
    this.fileId = const Value.absent(),
    this.size = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteFileIdsCompanion.insert({
    required String key,
    required String fileId,
    this.size = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       fileId = Value(fileId);
  static Insertable<RemoteFileIdRow> custom({
    Expression<String>? key,
    Expression<String>? fileId,
    Expression<int>? size,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (fileId != null) 'file_id': fileId,
      if (size != null) 'size': size,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteFileIdsCompanion copyWith({
    Value<String>? key,
    Value<String>? fileId,
    Value<int?>? size,
    Value<int?>? createdAt,
    Value<int>? rowid,
  }) {
    return RemoteFileIdsCompanion(
      key: key ?? this.key,
      fileId: fileId ?? this.fileId,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteFileIdsCompanion(')
          ..write('key: $key, ')
          ..write('fileId: $fileId, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlobIndexTable extends BlobIndex
    with TableInfo<$BlobIndexTable, BlobIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlobIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _plainHashMeta = const VerificationMeta(
    'plainHash',
  );
  @override
  late final GeneratedColumn<String> plainHash = GeneratedColumn<String>(
    'plain_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobKeyMeta = const VerificationMeta(
    'blobKey',
  );
  @override
  late final GeneratedColumn<String> blobKey = GeneratedColumn<String>(
    'blob_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<int> seenAt = GeneratedColumn<int>(
    'seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [plainHash, blobKey, size, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blob_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlobIndexRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plain_hash')) {
      context.handle(
        _plainHashMeta,
        plainHash.isAcceptableOrUnknown(data['plain_hash']!, _plainHashMeta),
      );
    } else if (isInserting) {
      context.missing(_plainHashMeta);
    }
    if (data.containsKey('blob_key')) {
      context.handle(
        _blobKeyMeta,
        blobKey.isAcceptableOrUnknown(data['blob_key']!, _blobKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_blobKeyMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_seenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {plainHash, blobKey};
  @override
  BlobIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobIndexRow(
      plainHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_hash'],
      )!,
      blobKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_key'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_at'],
      )!,
    );
  }

  @override
  $BlobIndexTable createAlias(String alias) {
    return $BlobIndexTable(attachedDatabase, alias);
  }
}

class BlobIndexRow extends DataClass implements Insertable<BlobIndexRow> {
  /// SHA-256 of unencrypted content.
  final String plainHash;

  /// Encrypted blob key (`blobs/<cipherHash>`).
  final String blobKey;

  /// Blob size in bytes.
  final int size;

  /// Timestamp in milliseconds UTC when blob existence was last verified remotely.
  final int seenAt;
  const BlobIndexRow({
    required this.plainHash,
    required this.blobKey,
    required this.size,
    required this.seenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plain_hash'] = Variable<String>(plainHash);
    map['blob_key'] = Variable<String>(blobKey);
    map['size'] = Variable<int>(size);
    map['seen_at'] = Variable<int>(seenAt);
    return map;
  }

  BlobIndexCompanion toCompanion(bool nullToAbsent) {
    return BlobIndexCompanion(
      plainHash: Value(plainHash),
      blobKey: Value(blobKey),
      size: Value(size),
      seenAt: Value(seenAt),
    );
  }

  factory BlobIndexRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobIndexRow(
      plainHash: serializer.fromJson<String>(json['plainHash']),
      blobKey: serializer.fromJson<String>(json['blobKey']),
      size: serializer.fromJson<int>(json['size']),
      seenAt: serializer.fromJson<int>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'plainHash': serializer.toJson<String>(plainHash),
      'blobKey': serializer.toJson<String>(blobKey),
      'size': serializer.toJson<int>(size),
      'seenAt': serializer.toJson<int>(seenAt),
    };
  }

  BlobIndexRow copyWith({
    String? plainHash,
    String? blobKey,
    int? size,
    int? seenAt,
  }) => BlobIndexRow(
    plainHash: plainHash ?? this.plainHash,
    blobKey: blobKey ?? this.blobKey,
    size: size ?? this.size,
    seenAt: seenAt ?? this.seenAt,
  );
  BlobIndexRow copyWithCompanion(BlobIndexCompanion data) {
    return BlobIndexRow(
      plainHash: data.plainHash.present ? data.plainHash.value : this.plainHash,
      blobKey: data.blobKey.present ? data.blobKey.value : this.blobKey,
      size: data.size.present ? data.size.value : this.size,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobIndexRow(')
          ..write('plainHash: $plainHash, ')
          ..write('blobKey: $blobKey, ')
          ..write('size: $size, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(plainHash, blobKey, size, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobIndexRow &&
          other.plainHash == this.plainHash &&
          other.blobKey == this.blobKey &&
          other.size == this.size &&
          other.seenAt == this.seenAt);
}

class BlobIndexCompanion extends UpdateCompanion<BlobIndexRow> {
  final Value<String> plainHash;
  final Value<String> blobKey;
  final Value<int> size;
  final Value<int> seenAt;
  final Value<int> rowid;
  const BlobIndexCompanion({
    this.plainHash = const Value.absent(),
    this.blobKey = const Value.absent(),
    this.size = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobIndexCompanion.insert({
    required String plainHash,
    required String blobKey,
    required int size,
    required int seenAt,
    this.rowid = const Value.absent(),
  }) : plainHash = Value(plainHash),
       blobKey = Value(blobKey),
       size = Value(size),
       seenAt = Value(seenAt);
  static Insertable<BlobIndexRow> custom({
    Expression<String>? plainHash,
    Expression<String>? blobKey,
    Expression<int>? size,
    Expression<int>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (plainHash != null) 'plain_hash': plainHash,
      if (blobKey != null) 'blob_key': blobKey,
      if (size != null) 'size': size,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobIndexCompanion copyWith({
    Value<String>? plainHash,
    Value<String>? blobKey,
    Value<int>? size,
    Value<int>? seenAt,
    Value<int>? rowid,
  }) {
    return BlobIndexCompanion(
      plainHash: plainHash ?? this.plainHash,
      blobKey: blobKey ?? this.blobKey,
      size: size ?? this.size,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (plainHash.present) {
      map['plain_hash'] = Variable<String>(plainHash.value);
    }
    if (blobKey.present) {
      map['blob_key'] = Variable<String>(blobKey.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<int>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobIndexCompanion(')
          ..write('plainHash: $plainHash, ')
          ..write('blobKey: $blobKey, ')
          ..write('size: $size, ')
          ..write('seenAt: $seenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLogTable extends SyncLog with TableInfo<$SyncLogTable, SyncLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherPathMeta = const VerificationMeta(
    'otherPath',
  );
  @override
  late final GeneratedColumn<String> otherPath = GeneratedColumn<String>(
    'other_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    time,
    level,
    kind,
    path,
    otherPath,
    deviceName,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('other_path')) {
      context.handle(
        _otherPathMeta,
        otherPath.isAcceptableOrUnknown(data['other_path']!, _otherPathMeta),
      );
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      otherPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_path'],
      ),
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $SyncLogTable createAlias(String alias) {
    return $SyncLogTable(attachedDatabase, alias);
  }
}

class SyncLogRow extends DataClass implements Insertable<SyncLogRow> {
  /// Unique auto-incrementing ID.
  final int id;

  /// Timestamp in milliseconds UTC.
  final int time;

  /// Log level string ('info', 'warning', 'error').
  final String level;

  /// Event kind ('upload', 'download', 'conflict', 'delete', etc.).
  final String kind;

  /// Relevant primary vault path.
  final String? path;

  /// Relevant secondary vault path (e.g. destination for move).
  final String? otherPath;

  /// Originating device name.
  final String? deviceName;

  /// Additional details or error message.
  final String? detail;
  const SyncLogRow({
    required this.id,
    required this.time,
    required this.level,
    required this.kind,
    this.path,
    this.otherPath,
    this.deviceName,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<int>(time);
    map['level'] = Variable<String>(level);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || otherPath != null) {
      map['other_path'] = Variable<String>(otherPath);
    }
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  SyncLogCompanion toCompanion(bool nullToAbsent) {
    return SyncLogCompanion(
      id: Value(id),
      time: Value(time),
      level: Value(level),
      kind: Value(kind),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      otherPath: otherPath == null && nullToAbsent
          ? const Value.absent()
          : Value(otherPath),
      deviceName: deviceName == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceName),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
    );
  }

  factory SyncLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLogRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<int>(json['time']),
      level: serializer.fromJson<String>(json['level']),
      kind: serializer.fromJson<String>(json['kind']),
      path: serializer.fromJson<String?>(json['path']),
      otherPath: serializer.fromJson<String?>(json['otherPath']),
      deviceName: serializer.fromJson<String?>(json['deviceName']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<int>(time),
      'level': serializer.toJson<String>(level),
      'kind': serializer.toJson<String>(kind),
      'path': serializer.toJson<String?>(path),
      'otherPath': serializer.toJson<String?>(otherPath),
      'deviceName': serializer.toJson<String?>(deviceName),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  SyncLogRow copyWith({
    int? id,
    int? time,
    String? level,
    String? kind,
    Value<String?> path = const Value.absent(),
    Value<String?> otherPath = const Value.absent(),
    Value<String?> deviceName = const Value.absent(),
    Value<String?> detail = const Value.absent(),
  }) => SyncLogRow(
    id: id ?? this.id,
    time: time ?? this.time,
    level: level ?? this.level,
    kind: kind ?? this.kind,
    path: path.present ? path.value : this.path,
    otherPath: otherPath.present ? otherPath.value : this.otherPath,
    deviceName: deviceName.present ? deviceName.value : this.deviceName,
    detail: detail.present ? detail.value : this.detail,
  );
  SyncLogRow copyWithCompanion(SyncLogCompanion data) {
    return SyncLogRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      level: data.level.present ? data.level.value : this.level,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      otherPath: data.otherPath.present ? data.otherPath.value : this.otherPath,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('level: $level, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('otherPath: $otherPath, ')
          ..write('deviceName: $deviceName, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, time, level, kind, path, otherPath, deviceName, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.level == this.level &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.otherPath == this.otherPath &&
          other.deviceName == this.deviceName &&
          other.detail == this.detail);
}

class SyncLogCompanion extends UpdateCompanion<SyncLogRow> {
  final Value<int> id;
  final Value<int> time;
  final Value<String> level;
  final Value<String> kind;
  final Value<String?> path;
  final Value<String?> otherPath;
  final Value<String?> deviceName;
  final Value<String?> detail;
  const SyncLogCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.level = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.otherPath = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.detail = const Value.absent(),
  });
  SyncLogCompanion.insert({
    this.id = const Value.absent(),
    required int time,
    required String level,
    required String kind,
    this.path = const Value.absent(),
    this.otherPath = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.detail = const Value.absent(),
  }) : time = Value(time),
       level = Value(level),
       kind = Value(kind);
  static Insertable<SyncLogRow> custom({
    Expression<int>? id,
    Expression<int>? time,
    Expression<String>? level,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<String>? otherPath,
    Expression<String>? deviceName,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (level != null) 'level': level,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (otherPath != null) 'other_path': otherPath,
      if (deviceName != null) 'device_name': deviceName,
      if (detail != null) 'detail': detail,
    });
  }

  SyncLogCompanion copyWith({
    Value<int>? id,
    Value<int>? time,
    Value<String>? level,
    Value<String>? kind,
    Value<String?>? path,
    Value<String?>? otherPath,
    Value<String?>? deviceName,
    Value<String?>? detail,
  }) {
    return SyncLogCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      level: level ?? this.level,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      otherPath: otherPath ?? this.otherPath,
      deviceName: deviceName ?? this.deviceName,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (otherPath.present) {
      map['other_path'] = Variable<String>(otherPath.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('level: $level, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('otherPath: $otherPath, ')
          ..write('deviceName: $deviceName, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $ConflictsTable extends Conflicts
    with TableInfo<$ConflictsTable, ConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyPathMeta = const VerificationMeta(
    'copyPath',
  );
  @override
  late final GeneratedColumn<String> copyPath = GeneratedColumn<String>(
    'copy_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _otherDeviceMeta = const VerificationMeta(
    'otherDevice',
  );
  @override
  late final GeneratedColumn<String> otherDevice = GeneratedColumn<String>(
    'other_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedMeta = const VerificationMeta(
    'resolved',
  );
  @override
  late final GeneratedColumn<int> resolved = GeneratedColumn<int>(
    'resolved',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    time,
    path,
    copyPath,
    kind,
    otherDevice,
    resolved,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('copy_path')) {
      context.handle(
        _copyPathMeta,
        copyPath.isAcceptableOrUnknown(data['copy_path']!, _copyPathMeta),
      );
    } else if (isInserting) {
      context.missing(_copyPathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('other_device')) {
      context.handle(
        _otherDeviceMeta,
        otherDevice.isAcceptableOrUnknown(
          data['other_device']!,
          _otherDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_otherDeviceMeta);
    }
    if (data.containsKey('resolved')) {
      context.handle(
        _resolvedMeta,
        resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta),
      );
    } else if (isInserting) {
      context.missing(_resolvedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      copyPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copy_path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      otherDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_device'],
      )!,
      resolved: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved'],
      )!,
    );
  }

  @override
  $ConflictsTable createAlias(String alias) {
    return $ConflictsTable(attachedDatabase, alias);
  }
}

class ConflictRow extends DataClass implements Insertable<ConflictRow> {
  /// Unique auto-incrementing ID.
  final int id;

  /// Timestamp in milliseconds UTC.
  final int time;

  /// Original file path.
  final String path;

  /// Preserved conflict copy path (e.g. `Note (Conflict from Phone).md`).
  final String copyPath;

  /// Conflict type ('content', 'case', 'delete_edit').
  final String kind;

  /// Name of the competing device.
  final String otherDevice;

  /// 1 if resolved by user, 0 if active.
  final int resolved;
  const ConflictRow({
    required this.id,
    required this.time,
    required this.path,
    required this.copyPath,
    required this.kind,
    required this.otherDevice,
    required this.resolved,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<int>(time);
    map['path'] = Variable<String>(path);
    map['copy_path'] = Variable<String>(copyPath);
    map['kind'] = Variable<String>(kind);
    map['other_device'] = Variable<String>(otherDevice);
    map['resolved'] = Variable<int>(resolved);
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      id: Value(id),
      time: Value(time),
      path: Value(path),
      copyPath: Value(copyPath),
      kind: Value(kind),
      otherDevice: Value(otherDevice),
      resolved: Value(resolved),
    );
  }

  factory ConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<int>(json['time']),
      path: serializer.fromJson<String>(json['path']),
      copyPath: serializer.fromJson<String>(json['copyPath']),
      kind: serializer.fromJson<String>(json['kind']),
      otherDevice: serializer.fromJson<String>(json['otherDevice']),
      resolved: serializer.fromJson<int>(json['resolved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<int>(time),
      'path': serializer.toJson<String>(path),
      'copyPath': serializer.toJson<String>(copyPath),
      'kind': serializer.toJson<String>(kind),
      'otherDevice': serializer.toJson<String>(otherDevice),
      'resolved': serializer.toJson<int>(resolved),
    };
  }

  ConflictRow copyWith({
    int? id,
    int? time,
    String? path,
    String? copyPath,
    String? kind,
    String? otherDevice,
    int? resolved,
  }) => ConflictRow(
    id: id ?? this.id,
    time: time ?? this.time,
    path: path ?? this.path,
    copyPath: copyPath ?? this.copyPath,
    kind: kind ?? this.kind,
    otherDevice: otherDevice ?? this.otherDevice,
    resolved: resolved ?? this.resolved,
  );
  ConflictRow copyWithCompanion(ConflictsCompanion data) {
    return ConflictRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      path: data.path.present ? data.path.value : this.path,
      copyPath: data.copyPath.present ? data.copyPath.value : this.copyPath,
      kind: data.kind.present ? data.kind.value : this.kind,
      otherDevice: data.otherDevice.present
          ? data.otherDevice.value
          : this.otherDevice,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('path: $path, ')
          ..write('copyPath: $copyPath, ')
          ..write('kind: $kind, ')
          ..write('otherDevice: $otherDevice, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, time, path, copyPath, kind, otherDevice, resolved);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.path == this.path &&
          other.copyPath == this.copyPath &&
          other.kind == this.kind &&
          other.otherDevice == this.otherDevice &&
          other.resolved == this.resolved);
}

class ConflictsCompanion extends UpdateCompanion<ConflictRow> {
  final Value<int> id;
  final Value<int> time;
  final Value<String> path;
  final Value<String> copyPath;
  final Value<String> kind;
  final Value<String> otherDevice;
  final Value<int> resolved;
  const ConflictsCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.path = const Value.absent(),
    this.copyPath = const Value.absent(),
    this.kind = const Value.absent(),
    this.otherDevice = const Value.absent(),
    this.resolved = const Value.absent(),
  });
  ConflictsCompanion.insert({
    this.id = const Value.absent(),
    required int time,
    required String path,
    required String copyPath,
    required String kind,
    required String otherDevice,
    required int resolved,
  }) : time = Value(time),
       path = Value(path),
       copyPath = Value(copyPath),
       kind = Value(kind),
       otherDevice = Value(otherDevice),
       resolved = Value(resolved);
  static Insertable<ConflictRow> custom({
    Expression<int>? id,
    Expression<int>? time,
    Expression<String>? path,
    Expression<String>? copyPath,
    Expression<String>? kind,
    Expression<String>? otherDevice,
    Expression<int>? resolved,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (path != null) 'path': path,
      if (copyPath != null) 'copy_path': copyPath,
      if (kind != null) 'kind': kind,
      if (otherDevice != null) 'other_device': otherDevice,
      if (resolved != null) 'resolved': resolved,
    });
  }

  ConflictsCompanion copyWith({
    Value<int>? id,
    Value<int>? time,
    Value<String>? path,
    Value<String>? copyPath,
    Value<String>? kind,
    Value<String>? otherDevice,
    Value<int>? resolved,
  }) {
    return ConflictsCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      path: path ?? this.path,
      copyPath: copyPath ?? this.copyPath,
      kind: kind ?? this.kind,
      otherDevice: otherDevice ?? this.otherDevice,
      resolved: resolved ?? this.resolved,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (copyPath.present) {
      map['copy_path'] = Variable<String>(copyPath.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (otherDevice.present) {
      map['other_device'] = Variable<String>(otherDevice.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<int>(resolved.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('path: $path, ')
          ..write('copyPath: $copyPath, ')
          ..write('kind: $kind, ')
          ..write('otherDevice: $otherDevice, ')
          ..write('resolved: $resolved')
          ..write(')'))
        .toString();
  }
}

class $BackupsTable extends Backups with TableInfo<$BackupsTable, BackupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  @override
  late final GeneratedColumn<String> stamp = GeneratedColumn<String>(
    'stamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestKeyMeta = const VerificationMeta(
    'manifestKey',
  );
  @override
  late final GeneratedColumn<String> manifestKey = GeneratedColumn<String>(
    'manifest_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileCountMeta = const VerificationMeta(
    'fileCount',
  );
  @override
  late final GeneratedColumn<int> fileCount = GeneratedColumn<int>(
    'file_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    stamp,
    manifestKey,
    fileCount,
    totalBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backups';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('stamp')) {
      context.handle(
        _stampMeta,
        stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta),
      );
    } else if (isInserting) {
      context.missing(_stampMeta);
    }
    if (data.containsKey('manifest_key')) {
      context.handle(
        _manifestKeyMeta,
        manifestKey.isAcceptableOrUnknown(
          data['manifest_key']!,
          _manifestKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestKeyMeta);
    }
    if (data.containsKey('file_count')) {
      context.handle(
        _fileCountMeta,
        fileCount.isAcceptableOrUnknown(data['file_count']!, _fileCountMeta),
      );
    } else if (isInserting) {
      context.missing(_fileCountMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stamp};
  @override
  BackupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRow(
      stamp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stamp'],
      )!,
      manifestKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_key'],
      )!,
      fileCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_count'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BackupsTable createAlias(String alias) {
    return $BackupsTable(attachedDatabase, alias);
  }
}

class BackupRow extends DataClass implements Insertable<BackupRow> {
  /// Backup timestamp stamp string (`yyyyMMddTHHmmssZ`).
  final String stamp;

  /// Remote manifest key (`backups/<stamp>/manifest.json.enc`).
  final String manifestKey;

  /// Total files in the backup.
  final int fileCount;

  /// Total bytes of files in the backup.
  final int totalBytes;

  /// Creation time in milliseconds UTC.
  final int createdAt;
  const BackupRow({
    required this.stamp,
    required this.manifestKey,
    required this.fileCount,
    required this.totalBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['stamp'] = Variable<String>(stamp);
    map['manifest_key'] = Variable<String>(manifestKey);
    map['file_count'] = Variable<int>(fileCount);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BackupsCompanion toCompanion(bool nullToAbsent) {
    return BackupsCompanion(
      stamp: Value(stamp),
      manifestKey: Value(manifestKey),
      fileCount: Value(fileCount),
      totalBytes: Value(totalBytes),
      createdAt: Value(createdAt),
    );
  }

  factory BackupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRow(
      stamp: serializer.fromJson<String>(json['stamp']),
      manifestKey: serializer.fromJson<String>(json['manifestKey']),
      fileCount: serializer.fromJson<int>(json['fileCount']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stamp': serializer.toJson<String>(stamp),
      'manifestKey': serializer.toJson<String>(manifestKey),
      'fileCount': serializer.toJson<int>(fileCount),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BackupRow copyWith({
    String? stamp,
    String? manifestKey,
    int? fileCount,
    int? totalBytes,
    int? createdAt,
  }) => BackupRow(
    stamp: stamp ?? this.stamp,
    manifestKey: manifestKey ?? this.manifestKey,
    fileCount: fileCount ?? this.fileCount,
    totalBytes: totalBytes ?? this.totalBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  BackupRow copyWithCompanion(BackupsCompanion data) {
    return BackupRow(
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
      manifestKey: data.manifestKey.present
          ? data.manifestKey.value
          : this.manifestKey,
      fileCount: data.fileCount.present ? data.fileCount.value : this.fileCount,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRow(')
          ..write('stamp: $stamp, ')
          ..write('manifestKey: $manifestKey, ')
          ..write('fileCount: $fileCount, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(stamp, manifestKey, fileCount, totalBytes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRow &&
          other.stamp == this.stamp &&
          other.manifestKey == this.manifestKey &&
          other.fileCount == this.fileCount &&
          other.totalBytes == this.totalBytes &&
          other.createdAt == this.createdAt);
}

class BackupsCompanion extends UpdateCompanion<BackupRow> {
  final Value<String> stamp;
  final Value<String> manifestKey;
  final Value<int> fileCount;
  final Value<int> totalBytes;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BackupsCompanion({
    this.stamp = const Value.absent(),
    this.manifestKey = const Value.absent(),
    this.fileCount = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupsCompanion.insert({
    required String stamp,
    required String manifestKey,
    required int fileCount,
    required int totalBytes,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : stamp = Value(stamp),
       manifestKey = Value(manifestKey),
       fileCount = Value(fileCount),
       totalBytes = Value(totalBytes),
       createdAt = Value(createdAt);
  static Insertable<BackupRow> custom({
    Expression<String>? stamp,
    Expression<String>? manifestKey,
    Expression<int>? fileCount,
    Expression<int>? totalBytes,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stamp != null) 'stamp': stamp,
      if (manifestKey != null) 'manifest_key': manifestKey,
      if (fileCount != null) 'file_count': fileCount,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupsCompanion copyWith({
    Value<String>? stamp,
    Value<String>? manifestKey,
    Value<int>? fileCount,
    Value<int>? totalBytes,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BackupsCompanion(
      stamp: stamp ?? this.stamp,
      manifestKey: manifestKey ?? this.manifestKey,
      fileCount: fileCount ?? this.fileCount,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stamp.present) {
      map['stamp'] = Variable<String>(stamp.value);
    }
    if (manifestKey.present) {
      map['manifest_key'] = Variable<String>(manifestKey.value);
    }
    if (fileCount.present) {
      map['file_count'] = Variable<int>(fileCount.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupsCompanion(')
          ..write('stamp: $stamp, ')
          ..write('manifestKey: $manifestKey, ')
          ..write('fileCount: $fileCount, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupVerificationsTable extends BackupVerifications
    with TableInfo<$BackupVerificationsTable, BackupVerificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupVerificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  @override
  late final GeneratedColumn<String> stamp = GeneratedColumn<String>(
    'stamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampledMeta = const VerificationMeta(
    'sampled',
  );
  @override
  late final GeneratedColumn<int> sampled = GeneratedColumn<int>(
    'sampled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<int> ok = GeneratedColumn<int>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<int> failed = GeneratedColumn<int>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedKeysMeta = const VerificationMeta(
    'failedKeys',
  );
  @override
  late final GeneratedColumn<String> failedKeys = GeneratedColumn<String>(
    'failed_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    time,
    stamp,
    sampled,
    ok,
    failed,
    failedKeys,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_verifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupVerificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('stamp')) {
      context.handle(
        _stampMeta,
        stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta),
      );
    } else if (isInserting) {
      context.missing(_stampMeta);
    }
    if (data.containsKey('sampled')) {
      context.handle(
        _sampledMeta,
        sampled.isAcceptableOrUnknown(data['sampled']!, _sampledMeta),
      );
    } else if (isInserting) {
      context.missing(_sampledMeta);
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    } else if (isInserting) {
      context.missing(_okMeta);
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    } else if (isInserting) {
      context.missing(_failedMeta);
    }
    if (data.containsKey('failed_keys')) {
      context.handle(
        _failedKeysMeta,
        failedKeys.isAcceptableOrUnknown(data['failed_keys']!, _failedKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_failedKeysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupVerificationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupVerificationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      stamp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stamp'],
      )!,
      sampled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sampled'],
      )!,
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ok'],
      )!,
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed'],
      )!,
      failedKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failed_keys'],
      )!,
    );
  }

  @override
  $BackupVerificationsTable createAlias(String alias) {
    return $BackupVerificationsTable(attachedDatabase, alias);
  }
}

class BackupVerificationRow extends DataClass
    implements Insertable<BackupVerificationRow> {
  /// Unique auto-incrementing ID.
  final int id;

  /// Verification run time in milliseconds UTC.
  final int time;

  /// Backup timestamp string verified.
  final String stamp;

  /// Number of sampled blobs checked.
  final int sampled;

  /// Number of verified OK blobs.
  final int ok;

  /// Number of failed or missing blobs.
  final int failed;

  /// JSON list of failed blob keys.
  final String failedKeys;
  const BackupVerificationRow({
    required this.id,
    required this.time,
    required this.stamp,
    required this.sampled,
    required this.ok,
    required this.failed,
    required this.failedKeys,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<int>(time);
    map['stamp'] = Variable<String>(stamp);
    map['sampled'] = Variable<int>(sampled);
    map['ok'] = Variable<int>(ok);
    map['failed'] = Variable<int>(failed);
    map['failed_keys'] = Variable<String>(failedKeys);
    return map;
  }

  BackupVerificationsCompanion toCompanion(bool nullToAbsent) {
    return BackupVerificationsCompanion(
      id: Value(id),
      time: Value(time),
      stamp: Value(stamp),
      sampled: Value(sampled),
      ok: Value(ok),
      failed: Value(failed),
      failedKeys: Value(failedKeys),
    );
  }

  factory BackupVerificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupVerificationRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<int>(json['time']),
      stamp: serializer.fromJson<String>(json['stamp']),
      sampled: serializer.fromJson<int>(json['sampled']),
      ok: serializer.fromJson<int>(json['ok']),
      failed: serializer.fromJson<int>(json['failed']),
      failedKeys: serializer.fromJson<String>(json['failedKeys']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<int>(time),
      'stamp': serializer.toJson<String>(stamp),
      'sampled': serializer.toJson<int>(sampled),
      'ok': serializer.toJson<int>(ok),
      'failed': serializer.toJson<int>(failed),
      'failedKeys': serializer.toJson<String>(failedKeys),
    };
  }

  BackupVerificationRow copyWith({
    int? id,
    int? time,
    String? stamp,
    int? sampled,
    int? ok,
    int? failed,
    String? failedKeys,
  }) => BackupVerificationRow(
    id: id ?? this.id,
    time: time ?? this.time,
    stamp: stamp ?? this.stamp,
    sampled: sampled ?? this.sampled,
    ok: ok ?? this.ok,
    failed: failed ?? this.failed,
    failedKeys: failedKeys ?? this.failedKeys,
  );
  BackupVerificationRow copyWithCompanion(BackupVerificationsCompanion data) {
    return BackupVerificationRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
      sampled: data.sampled.present ? data.sampled.value : this.sampled,
      ok: data.ok.present ? data.ok.value : this.ok,
      failed: data.failed.present ? data.failed.value : this.failed,
      failedKeys: data.failedKeys.present
          ? data.failedKeys.value
          : this.failedKeys,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupVerificationRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('stamp: $stamp, ')
          ..write('sampled: $sampled, ')
          ..write('ok: $ok, ')
          ..write('failed: $failed, ')
          ..write('failedKeys: $failedKeys')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, time, stamp, sampled, ok, failed, failedKeys);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupVerificationRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.stamp == this.stamp &&
          other.sampled == this.sampled &&
          other.ok == this.ok &&
          other.failed == this.failed &&
          other.failedKeys == this.failedKeys);
}

class BackupVerificationsCompanion
    extends UpdateCompanion<BackupVerificationRow> {
  final Value<int> id;
  final Value<int> time;
  final Value<String> stamp;
  final Value<int> sampled;
  final Value<int> ok;
  final Value<int> failed;
  final Value<String> failedKeys;
  const BackupVerificationsCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.stamp = const Value.absent(),
    this.sampled = const Value.absent(),
    this.ok = const Value.absent(),
    this.failed = const Value.absent(),
    this.failedKeys = const Value.absent(),
  });
  BackupVerificationsCompanion.insert({
    this.id = const Value.absent(),
    required int time,
    required String stamp,
    required int sampled,
    required int ok,
    required int failed,
    required String failedKeys,
  }) : time = Value(time),
       stamp = Value(stamp),
       sampled = Value(sampled),
       ok = Value(ok),
       failed = Value(failed),
       failedKeys = Value(failedKeys);
  static Insertable<BackupVerificationRow> custom({
    Expression<int>? id,
    Expression<int>? time,
    Expression<String>? stamp,
    Expression<int>? sampled,
    Expression<int>? ok,
    Expression<int>? failed,
    Expression<String>? failedKeys,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (stamp != null) 'stamp': stamp,
      if (sampled != null) 'sampled': sampled,
      if (ok != null) 'ok': ok,
      if (failed != null) 'failed': failed,
      if (failedKeys != null) 'failed_keys': failedKeys,
    });
  }

  BackupVerificationsCompanion copyWith({
    Value<int>? id,
    Value<int>? time,
    Value<String>? stamp,
    Value<int>? sampled,
    Value<int>? ok,
    Value<int>? failed,
    Value<String>? failedKeys,
  }) {
    return BackupVerificationsCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      stamp: stamp ?? this.stamp,
      sampled: sampled ?? this.sampled,
      ok: ok ?? this.ok,
      failed: failed ?? this.failed,
      failedKeys: failedKeys ?? this.failedKeys,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<String>(stamp.value);
    }
    if (sampled.present) {
      map['sampled'] = Variable<int>(sampled.value);
    }
    if (ok.present) {
      map['ok'] = Variable<int>(ok.value);
    }
    if (failed.present) {
      map['failed'] = Variable<int>(failed.value);
    }
    if (failedKeys.present) {
      map['failed_keys'] = Variable<String>(failedKeys.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupVerificationsCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('stamp: $stamp, ')
          ..write('sampled: $sampled, ')
          ..write('ok: $ok, ')
          ..write('failed: $failed, ')
          ..write('failedKeys: $failedKeys')
          ..write(')'))
        .toString();
  }
}

abstract class _$TephraSyncDatabase extends GeneratedDatabase {
  _$TephraSyncDatabase(QueryExecutor e) : super(e);
  $TephraSyncDatabaseManager get managers => $TephraSyncDatabaseManager(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $SyncedFilesTable syncedFiles = $SyncedFilesTable(this);
  late final $BasesTable bases = $BasesTable(this);
  late final $LocalHashCacheTable localHashCache = $LocalHashCacheTable(this);
  late final $RemoteEntriesTable remoteEntries = $RemoteEntriesTable(this);
  late final $RemoteHeadsTable remoteHeads = $RemoteHeadsTable(this);
  late final $JournalCursorsTable journalCursors = $JournalCursorsTable(this);
  late final $PendingOpsTable pendingOps = $PendingOpsTable(this);
  late final $RemoteFileIdsTable remoteFileIds = $RemoteFileIdsTable(this);
  late final $BlobIndexTable blobIndex = $BlobIndexTable(this);
  late final $SyncLogTable syncLog = $SyncLogTable(this);
  late final $ConflictsTable conflicts = $ConflictsTable(this);
  late final $BackupsTable backups = $BackupsTable(this);
  late final $BackupVerificationsTable backupVerifications =
      $BackupVerificationsTable(this);
  late final Index syncedFilesCaseKey = Index(
    'synced_files_case_key',
    'CREATE INDEX synced_files_case_key ON synced_files (case_key)',
  );
  late final Index remoteEntriesPath = Index(
    'remote_entries_path',
    'CREATE INDEX remote_entries_path ON remote_entries (path)',
  );
  late final Index remoteEntriesFromPath = Index(
    'remote_entries_from_path',
    'CREATE INDEX remote_entries_from_path ON remote_entries (from_path)',
  );
  late final Index remoteEntriesDeviceSeq = Index(
    'remote_entries_device_seq',
    'CREATE INDEX remote_entries_device_seq ON remote_entries (device_id, seq)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncMeta,
    syncedFiles,
    bases,
    localHashCache,
    remoteEntries,
    remoteHeads,
    journalCursors,
    pendingOps,
    remoteFileIds,
    blobIndex,
    syncLog,
    conflicts,
    backups,
    backupVerifications,
    syncedFilesCaseKey,
    remoteEntriesPath,
    remoteEntriesFromPath,
    remoteEntriesDeviceSeq,
  ];
}

typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$TephraSyncDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$TephraSyncDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetaRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $SyncMetaTable,
                    SyncMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaRow,
        BaseReferences<_$TephraSyncDatabase, $SyncMetaTable, SyncMetaRow>,
      ),
      SyncMetaRow,
      PrefetchHooks Function()
    >;
typedef $$SyncedFilesTableCreateCompanionBuilder =
    SyncedFilesCompanion Function({
      required String path,
      required String caseKey,
      required String hash,
      required int size,
      required int mtime,
      required String version,
      required String blobKeys,
      required int syncedAt,
      Value<int> rowid,
    });
typedef $$SyncedFilesTableUpdateCompanionBuilder =
    SyncedFilesCompanion Function({
      Value<String> path,
      Value<String> caseKey,
      Value<String> hash,
      Value<int> size,
      Value<int> mtime,
      Value<String> version,
      Value<String> blobKeys,
      Value<int> syncedAt,
      Value<int> rowid,
    });

class $$SyncedFilesTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseKey => $composableBuilder(
    column: $table.caseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobKeys => $composableBuilder(
    column: $table.blobKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncedFilesTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseKey => $composableBuilder(
    column: $table.caseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobKeys => $composableBuilder(
    column: $table.blobKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncedFilesTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $SyncedFilesTable> {
  $$SyncedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get caseKey =>
      $composableBuilder(column: $table.caseKey, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get blobKeys =>
      $composableBuilder(column: $table.blobKeys, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncedFilesTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $SyncedFilesTable,
          SyncedFileRow,
          $$SyncedFilesTableFilterComposer,
          $$SyncedFilesTableOrderingComposer,
          $$SyncedFilesTableAnnotationComposer,
          $$SyncedFilesTableCreateCompanionBuilder,
          $$SyncedFilesTableUpdateCompanionBuilder,
          (
            SyncedFileRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $SyncedFilesTable,
              SyncedFileRow
            >,
          ),
          SyncedFileRow,
          PrefetchHooks Function()
        > {
  $$SyncedFilesTableTableManager(
    _$TephraSyncDatabase db,
    $SyncedFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> caseKey = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> blobKeys = const Value.absent(),
                Value<int> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncedFilesCompanion(
                path: path,
                caseKey: caseKey,
                hash: hash,
                size: size,
                mtime: mtime,
                version: version,
                blobKeys: blobKeys,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String caseKey,
                required String hash,
                required int size,
                required int mtime,
                required String version,
                required String blobKeys,
                required int syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncedFilesCompanion.insert(
                path: path,
                caseKey: caseKey,
                hash: hash,
                size: size,
                mtime: mtime,
                version: version,
                blobKeys: blobKeys,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncedFilesTable, SyncedFileRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $SyncedFilesTable,
                    SyncedFileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncedFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $SyncedFilesTable,
      SyncedFileRow,
      $$SyncedFilesTableFilterComposer,
      $$SyncedFilesTableOrderingComposer,
      $$SyncedFilesTableAnnotationComposer,
      $$SyncedFilesTableCreateCompanionBuilder,
      $$SyncedFilesTableUpdateCompanionBuilder,
      (
        SyncedFileRow,
        BaseReferences<_$TephraSyncDatabase, $SyncedFilesTable, SyncedFileRow>,
      ),
      SyncedFileRow,
      PrefetchHooks Function()
    >;
typedef $$BasesTableCreateCompanionBuilder = BasesCompanion Function({
  required String path,
  required String hash,
  required Uint8List textGz,
  Value<int> rowid,
});
typedef $$BasesTableUpdateCompanionBuilder = BasesCompanion Function({
  Value<String> path,
  Value<String> hash,
  Value<Uint8List> textGz,
  Value<int> rowid,
});

class $$BasesTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $BasesTable> {
  $$BasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get textGz => $composableBuilder(
    column: $table.textGz,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BasesTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $BasesTable> {
  $$BasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get textGz => $composableBuilder(
    column: $table.textGz,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BasesTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $BasesTable> {
  $$BasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<Uint8List> get textGz =>
      $composableBuilder(column: $table.textGz, builder: (column) => column);
}

class $$BasesTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $BasesTable,
          BaseRow,
          $$BasesTableFilterComposer,
          $$BasesTableOrderingComposer,
          $$BasesTableAnnotationComposer,
          $$BasesTableCreateCompanionBuilder,
          $$BasesTableUpdateCompanionBuilder,
          (BaseRow, BaseReferences<_$TephraSyncDatabase, $BasesTable, BaseRow>),
          BaseRow,
          PrefetchHooks Function()
        > {
  $$BasesTableTableManager(_$TephraSyncDatabase db, $BasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<Uint8List> textGz = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BasesCompanion(
                path: path,
                hash: hash,
                textGz: textGz,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String hash,
                required Uint8List textGz,
                Value<int> rowid = const Value.absent(),
              }) => BasesCompanion.insert(
                path: path,
                hash: hash,
                textGz: textGz,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BasesTable, BaseRow>(table),
                  BaseReferences<_$TephraSyncDatabase, $BasesTable, BaseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BasesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $BasesTable,
      BaseRow,
      $$BasesTableFilterComposer,
      $$BasesTableOrderingComposer,
      $$BasesTableAnnotationComposer,
      $$BasesTableCreateCompanionBuilder,
      $$BasesTableUpdateCompanionBuilder,
      (BaseRow, BaseReferences<_$TephraSyncDatabase, $BasesTable, BaseRow>),
      BaseRow,
      PrefetchHooks Function()
    >;
typedef $$LocalHashCacheTableCreateCompanionBuilder =
    LocalHashCacheCompanion Function({
      required String path,
      required int size,
      required int mtime,
      required String hash,
      Value<int> rowid,
    });
typedef $$LocalHashCacheTableUpdateCompanionBuilder =
    LocalHashCacheCompanion Function({
      Value<String> path,
      Value<int> size,
      Value<int> mtime,
      Value<String> hash,
      Value<int> rowid,
    });

class $$LocalHashCacheTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $LocalHashCacheTable> {
  $$LocalHashCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalHashCacheTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $LocalHashCacheTable> {
  $$LocalHashCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalHashCacheTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $LocalHashCacheTable> {
  $$LocalHashCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);
}

class $$LocalHashCacheTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $LocalHashCacheTable,
          LocalHashCacheRow,
          $$LocalHashCacheTableFilterComposer,
          $$LocalHashCacheTableOrderingComposer,
          $$LocalHashCacheTableAnnotationComposer,
          $$LocalHashCacheTableCreateCompanionBuilder,
          $$LocalHashCacheTableUpdateCompanionBuilder,
          (
            LocalHashCacheRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $LocalHashCacheTable,
              LocalHashCacheRow
            >,
          ),
          LocalHashCacheRow,
          PrefetchHooks Function()
        > {
  $$LocalHashCacheTableTableManager(
    _$TephraSyncDatabase db,
    $LocalHashCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalHashCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalHashCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalHashCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalHashCacheCompanion(
                path: path,
                size: size,
                mtime: mtime,
                hash: hash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int size,
                required int mtime,
                required String hash,
                Value<int> rowid = const Value.absent(),
              }) => LocalHashCacheCompanion.insert(
                path: path,
                size: size,
                mtime: mtime,
                hash: hash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalHashCacheTable, LocalHashCacheRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $LocalHashCacheTable,
                    LocalHashCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalHashCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $LocalHashCacheTable,
      LocalHashCacheRow,
      $$LocalHashCacheTableFilterComposer,
      $$LocalHashCacheTableOrderingComposer,
      $$LocalHashCacheTableAnnotationComposer,
      $$LocalHashCacheTableCreateCompanionBuilder,
      $$LocalHashCacheTableUpdateCompanionBuilder,
      (
        LocalHashCacheRow,
        BaseReferences<
          _$TephraSyncDatabase,
          $LocalHashCacheTable,
          LocalHashCacheRow
        >,
      ),
      LocalHashCacheRow,
      PrefetchHooks Function()
    >;
typedef $$RemoteEntriesTableCreateCompanionBuilder =
    RemoteEntriesCompanion Function({
      required String entryId,
      required String deviceId,
      required int seq,
      required String hlc,
      required String op,
      required String path,
      Value<String?> fromPath,
      Value<String?> hash,
      Value<int?> size,
      Value<int?> mtime,
      Value<String?> blobKeys,
      Value<String?> parent,
      Value<String?> targetParent,
      Value<String?> mergedParent,
      required int time,
      Value<int> rowid,
    });
typedef $$RemoteEntriesTableUpdateCompanionBuilder =
    RemoteEntriesCompanion Function({
      Value<String> entryId,
      Value<String> deviceId,
      Value<int> seq,
      Value<String> hlc,
      Value<String> op,
      Value<String> path,
      Value<String?> fromPath,
      Value<String?> hash,
      Value<int?> size,
      Value<int?> mtime,
      Value<String?> blobKeys,
      Value<String?> parent,
      Value<String?> targetParent,
      Value<String?> mergedParent,
      Value<int> time,
      Value<int> rowid,
    });

class $$RemoteEntriesTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $RemoteEntriesTable> {
  $$RemoteEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromPath => $composableBuilder(
    column: $table.fromPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobKeys => $composableBuilder(
    column: $table.blobKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetParent => $composableBuilder(
    column: $table.targetParent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mergedParent => $composableBuilder(
    column: $table.mergedParent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemoteEntriesTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $RemoteEntriesTable> {
  $$RemoteEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromPath => $composableBuilder(
    column: $table.fromPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobKeys => $composableBuilder(
    column: $table.blobKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetParent => $composableBuilder(
    column: $table.targetParent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mergedParent => $composableBuilder(
    column: $table.mergedParent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemoteEntriesTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $RemoteEntriesTable> {
  $$RemoteEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fromPath =>
      $composableBuilder(column: $table.fromPath, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get blobKeys =>
      $composableBuilder(column: $table.blobKeys, builder: (column) => column);

  GeneratedColumn<String> get parent =>
      $composableBuilder(column: $table.parent, builder: (column) => column);

  GeneratedColumn<String> get targetParent => $composableBuilder(
    column: $table.targetParent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mergedParent => $composableBuilder(
    column: $table.mergedParent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);
}

class $$RemoteEntriesTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $RemoteEntriesTable,
          RemoteEntryRow,
          $$RemoteEntriesTableFilterComposer,
          $$RemoteEntriesTableOrderingComposer,
          $$RemoteEntriesTableAnnotationComposer,
          $$RemoteEntriesTableCreateCompanionBuilder,
          $$RemoteEntriesTableUpdateCompanionBuilder,
          (
            RemoteEntryRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $RemoteEntriesTable,
              RemoteEntryRow
            >,
          ),
          RemoteEntryRow,
          PrefetchHooks Function()
        > {
  $$RemoteEntriesTableTableManager(
    _$TephraSyncDatabase db,
    $RemoteEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> fromPath = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<int?> mtime = const Value.absent(),
                Value<String?> blobKeys = const Value.absent(),
                Value<String?> parent = const Value.absent(),
                Value<String?> targetParent = const Value.absent(),
                Value<String?> mergedParent = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteEntriesCompanion(
                entryId: entryId,
                deviceId: deviceId,
                seq: seq,
                hlc: hlc,
                op: op,
                path: path,
                fromPath: fromPath,
                hash: hash,
                size: size,
                mtime: mtime,
                blobKeys: blobKeys,
                parent: parent,
                targetParent: targetParent,
                mergedParent: mergedParent,
                time: time,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String deviceId,
                required int seq,
                required String hlc,
                required String op,
                required String path,
                Value<String?> fromPath = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<int?> mtime = const Value.absent(),
                Value<String?> blobKeys = const Value.absent(),
                Value<String?> parent = const Value.absent(),
                Value<String?> targetParent = const Value.absent(),
                Value<String?> mergedParent = const Value.absent(),
                required int time,
                Value<int> rowid = const Value.absent(),
              }) => RemoteEntriesCompanion.insert(
                entryId: entryId,
                deviceId: deviceId,
                seq: seq,
                hlc: hlc,
                op: op,
                path: path,
                fromPath: fromPath,
                hash: hash,
                size: size,
                mtime: mtime,
                blobKeys: blobKeys,
                parent: parent,
                targetParent: targetParent,
                mergedParent: mergedParent,
                time: time,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemoteEntriesTable, RemoteEntryRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $RemoteEntriesTable,
                    RemoteEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemoteEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $RemoteEntriesTable,
      RemoteEntryRow,
      $$RemoteEntriesTableFilterComposer,
      $$RemoteEntriesTableOrderingComposer,
      $$RemoteEntriesTableAnnotationComposer,
      $$RemoteEntriesTableCreateCompanionBuilder,
      $$RemoteEntriesTableUpdateCompanionBuilder,
      (
        RemoteEntryRow,
        BaseReferences<
          _$TephraSyncDatabase,
          $RemoteEntriesTable,
          RemoteEntryRow
        >,
      ),
      RemoteEntryRow,
      PrefetchHooks Function()
    >;
typedef $$RemoteHeadsTableCreateCompanionBuilder =
    RemoteHeadsCompanion Function({
      required String path,
      required String entryId,
      required int isFork,
      Value<int> rowid,
    });
typedef $$RemoteHeadsTableUpdateCompanionBuilder =
    RemoteHeadsCompanion Function({
      Value<String> path,
      Value<String> entryId,
      Value<int> isFork,
      Value<int> rowid,
    });

class $$RemoteHeadsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $RemoteHeadsTable> {
  $$RemoteHeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isFork => $composableBuilder(
    column: $table.isFork,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemoteHeadsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $RemoteHeadsTable> {
  $$RemoteHeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isFork => $composableBuilder(
    column: $table.isFork,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemoteHeadsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $RemoteHeadsTable> {
  $$RemoteHeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get isFork =>
      $composableBuilder(column: $table.isFork, builder: (column) => column);
}

class $$RemoteHeadsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $RemoteHeadsTable,
          RemoteHeadRow,
          $$RemoteHeadsTableFilterComposer,
          $$RemoteHeadsTableOrderingComposer,
          $$RemoteHeadsTableAnnotationComposer,
          $$RemoteHeadsTableCreateCompanionBuilder,
          $$RemoteHeadsTableUpdateCompanionBuilder,
          (
            RemoteHeadRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $RemoteHeadsTable,
              RemoteHeadRow
            >,
          ),
          RemoteHeadRow,
          PrefetchHooks Function()
        > {
  $$RemoteHeadsTableTableManager(
    _$TephraSyncDatabase db,
    $RemoteHeadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteHeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteHeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteHeadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> isFork = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteHeadsCompanion(
                path: path,
                entryId: entryId,
                isFork: isFork,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String entryId,
                required int isFork,
                Value<int> rowid = const Value.absent(),
              }) => RemoteHeadsCompanion.insert(
                path: path,
                entryId: entryId,
                isFork: isFork,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemoteHeadsTable, RemoteHeadRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $RemoteHeadsTable,
                    RemoteHeadRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemoteHeadsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $RemoteHeadsTable,
      RemoteHeadRow,
      $$RemoteHeadsTableFilterComposer,
      $$RemoteHeadsTableOrderingComposer,
      $$RemoteHeadsTableAnnotationComposer,
      $$RemoteHeadsTableCreateCompanionBuilder,
      $$RemoteHeadsTableUpdateCompanionBuilder,
      (
        RemoteHeadRow,
        BaseReferences<_$TephraSyncDatabase, $RemoteHeadsTable, RemoteHeadRow>,
      ),
      RemoteHeadRow,
      PrefetchHooks Function()
    >;
typedef $$JournalCursorsTableCreateCompanionBuilder =
    JournalCursorsCompanion Function({
      required String deviceId,
      required int lastSeq,
      Value<String?> deviceName,
      Value<String?> platform,
      Value<int?> lastSeenAt,
      Value<int?> revokedAfterSeq,
      Value<int> rowid,
    });
typedef $$JournalCursorsTableUpdateCompanionBuilder =
    JournalCursorsCompanion Function({
      Value<String> deviceId,
      Value<int> lastSeq,
      Value<String?> deviceName,
      Value<String?> platform,
      Value<int?> lastSeenAt,
      Value<int?> revokedAfterSeq,
      Value<int> rowid,
    });

class $$JournalCursorsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $JournalCursorsTable> {
  $$JournalCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revokedAfterSeq => $composableBuilder(
    column: $table.revokedAfterSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalCursorsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $JournalCursorsTable> {
  $$JournalCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revokedAfterSeq => $composableBuilder(
    column: $table.revokedAfterSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalCursorsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $JournalCursorsTable> {
  $$JournalCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revokedAfterSeq => $composableBuilder(
    column: $table.revokedAfterSeq,
    builder: (column) => column,
  );
}

class $$JournalCursorsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $JournalCursorsTable,
          JournalCursorRow,
          $$JournalCursorsTableFilterComposer,
          $$JournalCursorsTableOrderingComposer,
          $$JournalCursorsTableAnnotationComposer,
          $$JournalCursorsTableCreateCompanionBuilder,
          $$JournalCursorsTableUpdateCompanionBuilder,
          (
            JournalCursorRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $JournalCursorsTable,
              JournalCursorRow
            >,
          ),
          JournalCursorRow,
          PrefetchHooks Function()
        > {
  $$JournalCursorsTableTableManager(
    _$TephraSyncDatabase db,
    $JournalCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<String?> deviceName = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> revokedAfterSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalCursorsCompanion(
                deviceId: deviceId,
                lastSeq: lastSeq,
                deviceName: deviceName,
                platform: platform,
                lastSeenAt: lastSeenAt,
                revokedAfterSeq: revokedAfterSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required int lastSeq,
                Value<String?> deviceName = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> revokedAfterSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalCursorsCompanion.insert(
                deviceId: deviceId,
                lastSeq: lastSeq,
                deviceName: deviceName,
                platform: platform,
                lastSeenAt: lastSeenAt,
                revokedAfterSeq: revokedAfterSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JournalCursorsTable, JournalCursorRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $JournalCursorsTable,
                    JournalCursorRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $JournalCursorsTable,
      JournalCursorRow,
      $$JournalCursorsTableFilterComposer,
      $$JournalCursorsTableOrderingComposer,
      $$JournalCursorsTableAnnotationComposer,
      $$JournalCursorsTableCreateCompanionBuilder,
      $$JournalCursorsTableUpdateCompanionBuilder,
      (
        JournalCursorRow,
        BaseReferences<
          _$TephraSyncDatabase,
          $JournalCursorsTable,
          JournalCursorRow
        >,
      ),
      JournalCursorRow,
      PrefetchHooks Function()
    >;
typedef $$PendingOpsTableCreateCompanionBuilder = PendingOpsCompanion Function({
  Value<int> id,
  required String kind,
  required String payload,
  required String state,
  required int createdAt,
  required int attempts,
  Value<String?> lastError,
});
typedef $$PendingOpsTableUpdateCompanionBuilder = PendingOpsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> payload,
  Value<String> state,
  Value<int> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});

class $$PendingOpsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $PendingOpsTable> {
  $$PendingOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOpsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $PendingOpsTable> {
  $$PendingOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOpsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $PendingOpsTable> {
  $$PendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingOpsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $PendingOpsTable,
          PendingOpRow,
          $$PendingOpsTableFilterComposer,
          $$PendingOpsTableOrderingComposer,
          $$PendingOpsTableAnnotationComposer,
          $$PendingOpsTableCreateCompanionBuilder,
          $$PendingOpsTableUpdateCompanionBuilder,
          (
            PendingOpRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $PendingOpsTable,
              PendingOpRow
            >,
          ),
          PendingOpRow,
          PrefetchHooks Function()
        > {
  $$PendingOpsTableTableManager(_$TephraSyncDatabase db, $PendingOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingOpsCompanion(
                id: id,
                kind: kind,
                payload: payload,
                state: state,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String payload,
                required String state,
                required int createdAt,
                required int attempts,
                Value<String?> lastError = const Value.absent(),
              }) => PendingOpsCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                state: state,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingOpsTable, PendingOpRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $PendingOpsTable,
                    PendingOpRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $PendingOpsTable,
      PendingOpRow,
      $$PendingOpsTableFilterComposer,
      $$PendingOpsTableOrderingComposer,
      $$PendingOpsTableAnnotationComposer,
      $$PendingOpsTableCreateCompanionBuilder,
      $$PendingOpsTableUpdateCompanionBuilder,
      (
        PendingOpRow,
        BaseReferences<_$TephraSyncDatabase, $PendingOpsTable, PendingOpRow>,
      ),
      PendingOpRow,
      PrefetchHooks Function()
    >;
typedef $$RemoteFileIdsTableCreateCompanionBuilder =
    RemoteFileIdsCompanion Function({
      required String key,
      required String fileId,
      Value<int?> size,
      Value<int?> createdAt,
      Value<int> rowid,
    });
typedef $$RemoteFileIdsTableUpdateCompanionBuilder =
    RemoteFileIdsCompanion Function({
      Value<String> key,
      Value<String> fileId,
      Value<int?> size,
      Value<int?> createdAt,
      Value<int> rowid,
    });

class $$RemoteFileIdsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $RemoteFileIdsTable> {
  $$RemoteFileIdsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemoteFileIdsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $RemoteFileIdsTable> {
  $$RemoteFileIdsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemoteFileIdsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $RemoteFileIdsTable> {
  $$RemoteFileIdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RemoteFileIdsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $RemoteFileIdsTable,
          RemoteFileIdRow,
          $$RemoteFileIdsTableFilterComposer,
          $$RemoteFileIdsTableOrderingComposer,
          $$RemoteFileIdsTableAnnotationComposer,
          $$RemoteFileIdsTableCreateCompanionBuilder,
          $$RemoteFileIdsTableUpdateCompanionBuilder,
          (
            RemoteFileIdRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $RemoteFileIdsTable,
              RemoteFileIdRow
            >,
          ),
          RemoteFileIdRow,
          PrefetchHooks Function()
        > {
  $$RemoteFileIdsTableTableManager(
    _$TephraSyncDatabase db,
    $RemoteFileIdsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteFileIdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteFileIdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteFileIdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteFileIdsCompanion(
                key: key,
                fileId: fileId,
                size: size,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String fileId,
                Value<int?> size = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteFileIdsCompanion.insert(
                key: key,
                fileId: fileId,
                size: size,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemoteFileIdsTable, RemoteFileIdRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $RemoteFileIdsTable,
                    RemoteFileIdRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemoteFileIdsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $RemoteFileIdsTable,
      RemoteFileIdRow,
      $$RemoteFileIdsTableFilterComposer,
      $$RemoteFileIdsTableOrderingComposer,
      $$RemoteFileIdsTableAnnotationComposer,
      $$RemoteFileIdsTableCreateCompanionBuilder,
      $$RemoteFileIdsTableUpdateCompanionBuilder,
      (
        RemoteFileIdRow,
        BaseReferences<
          _$TephraSyncDatabase,
          $RemoteFileIdsTable,
          RemoteFileIdRow
        >,
      ),
      RemoteFileIdRow,
      PrefetchHooks Function()
    >;
typedef $$BlobIndexTableCreateCompanionBuilder = BlobIndexCompanion Function({
  required String plainHash,
  required String blobKey,
  required int size,
  required int seenAt,
  Value<int> rowid,
});
typedef $$BlobIndexTableUpdateCompanionBuilder = BlobIndexCompanion Function({
  Value<String> plainHash,
  Value<String> blobKey,
  Value<int> size,
  Value<int> seenAt,
  Value<int> rowid,
});

class $$BlobIndexTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $BlobIndexTable> {
  $$BlobIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get plainHash => $composableBuilder(
    column: $table.plainHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobKey => $composableBuilder(
    column: $table.blobKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlobIndexTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $BlobIndexTable> {
  $$BlobIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get plainHash => $composableBuilder(
    column: $table.plainHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobKey => $composableBuilder(
    column: $table.blobKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlobIndexTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $BlobIndexTable> {
  $$BlobIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get plainHash =>
      $composableBuilder(column: $table.plainHash, builder: (column) => column);

  GeneratedColumn<String> get blobKey =>
      $composableBuilder(column: $table.blobKey, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);
}

class $$BlobIndexTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $BlobIndexTable,
          BlobIndexRow,
          $$BlobIndexTableFilterComposer,
          $$BlobIndexTableOrderingComposer,
          $$BlobIndexTableAnnotationComposer,
          $$BlobIndexTableCreateCompanionBuilder,
          $$BlobIndexTableUpdateCompanionBuilder,
          (
            BlobIndexRow,
            BaseReferences<_$TephraSyncDatabase, $BlobIndexTable, BlobIndexRow>,
          ),
          BlobIndexRow,
          PrefetchHooks Function()
        > {
  $$BlobIndexTableTableManager(_$TephraSyncDatabase db, $BlobIndexTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlobIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlobIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlobIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> plainHash = const Value.absent(),
                Value<String> blobKey = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> seenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobIndexCompanion(
                plainHash: plainHash,
                blobKey: blobKey,
                size: size,
                seenAt: seenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String plainHash,
                required String blobKey,
                required int size,
                required int seenAt,
                Value<int> rowid = const Value.absent(),
              }) => BlobIndexCompanion.insert(
                plainHash: plainHash,
                blobKey: blobKey,
                size: size,
                seenAt: seenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlobIndexTable, BlobIndexRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $BlobIndexTable,
                    BlobIndexRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlobIndexTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $BlobIndexTable,
      BlobIndexRow,
      $$BlobIndexTableFilterComposer,
      $$BlobIndexTableOrderingComposer,
      $$BlobIndexTableAnnotationComposer,
      $$BlobIndexTableCreateCompanionBuilder,
      $$BlobIndexTableUpdateCompanionBuilder,
      (
        BlobIndexRow,
        BaseReferences<_$TephraSyncDatabase, $BlobIndexTable, BlobIndexRow>,
      ),
      BlobIndexRow,
      PrefetchHooks Function()
    >;
typedef $$SyncLogTableCreateCompanionBuilder = SyncLogCompanion Function({
  Value<int> id,
  required int time,
  required String level,
  required String kind,
  Value<String?> path,
  Value<String?> otherPath,
  Value<String?> deviceName,
  Value<String?> detail,
});
typedef $$SyncLogTableUpdateCompanionBuilder = SyncLogCompanion Function({
  Value<int> id,
  Value<int> time,
  Value<String> level,
  Value<String> kind,
  Value<String?> path,
  Value<String?> otherPath,
  Value<String?> deviceName,
  Value<String?> detail,
});

class $$SyncLogTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $SyncLogTable> {
  $$SyncLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherPath => $composableBuilder(
    column: $table.otherPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLogTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $SyncLogTable> {
  $$SyncLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherPath => $composableBuilder(
    column: $table.otherPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLogTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $SyncLogTable> {
  $$SyncLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get otherPath =>
      $composableBuilder(column: $table.otherPath, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$SyncLogTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $SyncLogTable,
          SyncLogRow,
          $$SyncLogTableFilterComposer,
          $$SyncLogTableOrderingComposer,
          $$SyncLogTableAnnotationComposer,
          $$SyncLogTableCreateCompanionBuilder,
          $$SyncLogTableUpdateCompanionBuilder,
          (
            SyncLogRow,
            BaseReferences<_$TephraSyncDatabase, $SyncLogTable, SyncLogRow>,
          ),
          SyncLogRow,
          PrefetchHooks Function()
        > {
  $$SyncLogTableTableManager(_$TephraSyncDatabase db, $SyncLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> otherPath = const Value.absent(),
                Value<String?> deviceName = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => SyncLogCompanion(
                id: id,
                time: time,
                level: level,
                kind: kind,
                path: path,
                otherPath: otherPath,
                deviceName: deviceName,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int time,
                required String level,
                required String kind,
                Value<String?> path = const Value.absent(),
                Value<String?> otherPath = const Value.absent(),
                Value<String?> deviceName = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => SyncLogCompanion.insert(
                id: id,
                time: time,
                level: level,
                kind: kind,
                path: path,
                otherPath: otherPath,
                deviceName: deviceName,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncLogTable, SyncLogRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $SyncLogTable,
                    SyncLogRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLogTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $SyncLogTable,
      SyncLogRow,
      $$SyncLogTableFilterComposer,
      $$SyncLogTableOrderingComposer,
      $$SyncLogTableAnnotationComposer,
      $$SyncLogTableCreateCompanionBuilder,
      $$SyncLogTableUpdateCompanionBuilder,
      (
        SyncLogRow,
        BaseReferences<_$TephraSyncDatabase, $SyncLogTable, SyncLogRow>,
      ),
      SyncLogRow,
      PrefetchHooks Function()
    >;
typedef $$ConflictsTableCreateCompanionBuilder = ConflictsCompanion Function({
  Value<int> id,
  required int time,
  required String path,
  required String copyPath,
  required String kind,
  required String otherDevice,
  required int resolved,
});
typedef $$ConflictsTableUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<int> id,
  Value<int> time,
  Value<String> path,
  Value<String> copyPath,
  Value<String> kind,
  Value<String> otherDevice,
  Value<int> resolved,
});

class $$ConflictsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $ConflictsTable> {
  $$ConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get copyPath => $composableBuilder(
    column: $table.copyPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherDevice => $composableBuilder(
    column: $table.otherDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $ConflictsTable> {
  $$ConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get copyPath => $composableBuilder(
    column: $table.copyPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherDevice => $composableBuilder(
    column: $table.otherDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $ConflictsTable> {
  $$ConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get copyPath =>
      $composableBuilder(column: $table.copyPath, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get otherDevice => $composableBuilder(
    column: $table.otherDevice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);
}

class $$ConflictsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $ConflictsTable,
          ConflictRow,
          $$ConflictsTableFilterComposer,
          $$ConflictsTableOrderingComposer,
          $$ConflictsTableAnnotationComposer,
          $$ConflictsTableCreateCompanionBuilder,
          $$ConflictsTableUpdateCompanionBuilder,
          (
            ConflictRow,
            BaseReferences<_$TephraSyncDatabase, $ConflictsTable, ConflictRow>,
          ),
          ConflictRow,
          PrefetchHooks Function()
        > {
  $$ConflictsTableTableManager(_$TephraSyncDatabase db, $ConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> copyPath = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> otherDevice = const Value.absent(),
                Value<int> resolved = const Value.absent(),
              }) => ConflictsCompanion(
                id: id,
                time: time,
                path: path,
                copyPath: copyPath,
                kind: kind,
                otherDevice: otherDevice,
                resolved: resolved,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int time,
                required String path,
                required String copyPath,
                required String kind,
                required String otherDevice,
                required int resolved,
              }) => ConflictsCompanion.insert(
                id: id,
                time: time,
                path: path,
                copyPath: copyPath,
                kind: kind,
                otherDevice: otherDevice,
                resolved: resolved,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConflictsTable, ConflictRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $ConflictsTable,
                    ConflictRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $ConflictsTable,
      ConflictRow,
      $$ConflictsTableFilterComposer,
      $$ConflictsTableOrderingComposer,
      $$ConflictsTableAnnotationComposer,
      $$ConflictsTableCreateCompanionBuilder,
      $$ConflictsTableUpdateCompanionBuilder,
      (
        ConflictRow,
        BaseReferences<_$TephraSyncDatabase, $ConflictsTable, ConflictRow>,
      ),
      ConflictRow,
      PrefetchHooks Function()
    >;
typedef $$BackupsTableCreateCompanionBuilder = BackupsCompanion Function({
  required String stamp,
  required String manifestKey,
  required int fileCount,
  required int totalBytes,
  required int createdAt,
  Value<int> rowid,
});
typedef $$BackupsTableUpdateCompanionBuilder = BackupsCompanion Function({
  Value<String> stamp,
  Value<String> manifestKey,
  Value<int> fileCount,
  Value<int> totalBytes,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$BackupsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $BackupsTable> {
  $$BackupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestKey => $composableBuilder(
    column: $table.manifestKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileCount => $composableBuilder(
    column: $table.fileCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $BackupsTable> {
  $$BackupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestKey => $composableBuilder(
    column: $table.manifestKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileCount => $composableBuilder(
    column: $table.fileCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $BackupsTable> {
  $$BackupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);

  GeneratedColumn<String> get manifestKey => $composableBuilder(
    column: $table.manifestKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileCount =>
      $composableBuilder(column: $table.fileCount, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BackupsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $BackupsTable,
          BackupRow,
          $$BackupsTableFilterComposer,
          $$BackupsTableOrderingComposer,
          $$BackupsTableAnnotationComposer,
          $$BackupsTableCreateCompanionBuilder,
          $$BackupsTableUpdateCompanionBuilder,
          (
            BackupRow,
            BaseReferences<_$TephraSyncDatabase, $BackupsTable, BackupRow>,
          ),
          BackupRow,
          PrefetchHooks Function()
        > {
  $$BackupsTableTableManager(_$TephraSyncDatabase db, $BackupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stamp = const Value.absent(),
                Value<String> manifestKey = const Value.absent(),
                Value<int> fileCount = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupsCompanion(
                stamp: stamp,
                manifestKey: manifestKey,
                fileCount: fileCount,
                totalBytes: totalBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stamp,
                required String manifestKey,
                required int fileCount,
                required int totalBytes,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BackupsCompanion.insert(
                stamp: stamp,
                manifestKey: manifestKey,
                fileCount: fileCount,
                totalBytes: totalBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupsTable, BackupRow>(table),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $BackupsTable,
                    BackupRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $BackupsTable,
      BackupRow,
      $$BackupsTableFilterComposer,
      $$BackupsTableOrderingComposer,
      $$BackupsTableAnnotationComposer,
      $$BackupsTableCreateCompanionBuilder,
      $$BackupsTableUpdateCompanionBuilder,
      (
        BackupRow,
        BaseReferences<_$TephraSyncDatabase, $BackupsTable, BackupRow>,
      ),
      BackupRow,
      PrefetchHooks Function()
    >;
typedef $$BackupVerificationsTableCreateCompanionBuilder =
    BackupVerificationsCompanion Function({
      Value<int> id,
      required int time,
      required String stamp,
      required int sampled,
      required int ok,
      required int failed,
      required String failedKeys,
    });
typedef $$BackupVerificationsTableUpdateCompanionBuilder =
    BackupVerificationsCompanion Function({
      Value<int> id,
      Value<int> time,
      Value<String> stamp,
      Value<int> sampled,
      Value<int> ok,
      Value<int> failed,
      Value<String> failedKeys,
    });

class $$BackupVerificationsTableFilterComposer
    extends Composer<_$TephraSyncDatabase, $BackupVerificationsTable> {
  $$BackupVerificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampled => $composableBuilder(
    column: $table.sampled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failedKeys => $composableBuilder(
    column: $table.failedKeys,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupVerificationsTableOrderingComposer
    extends Composer<_$TephraSyncDatabase, $BackupVerificationsTable> {
  $$BackupVerificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampled => $composableBuilder(
    column: $table.sampled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failedKeys => $composableBuilder(
    column: $table.failedKeys,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupVerificationsTableAnnotationComposer
    extends Composer<_$TephraSyncDatabase, $BackupVerificationsTable> {
  $$BackupVerificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);

  GeneratedColumn<int> get sampled =>
      $composableBuilder(column: $table.sampled, builder: (column) => column);

  GeneratedColumn<int> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<int> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);

  GeneratedColumn<String> get failedKeys => $composableBuilder(
    column: $table.failedKeys,
    builder: (column) => column,
  );
}

class $$BackupVerificationsTableTableManager
    extends
        RootTableManager<
          _$TephraSyncDatabase,
          $BackupVerificationsTable,
          BackupVerificationRow,
          $$BackupVerificationsTableFilterComposer,
          $$BackupVerificationsTableOrderingComposer,
          $$BackupVerificationsTableAnnotationComposer,
          $$BackupVerificationsTableCreateCompanionBuilder,
          $$BackupVerificationsTableUpdateCompanionBuilder,
          (
            BackupVerificationRow,
            BaseReferences<
              _$TephraSyncDatabase,
              $BackupVerificationsTable,
              BackupVerificationRow
            >,
          ),
          BackupVerificationRow,
          PrefetchHooks Function()
        > {
  $$BackupVerificationsTableTableManager(
    _$TephraSyncDatabase db,
    $BackupVerificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupVerificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupVerificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BackupVerificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<String> stamp = const Value.absent(),
                Value<int> sampled = const Value.absent(),
                Value<int> ok = const Value.absent(),
                Value<int> failed = const Value.absent(),
                Value<String> failedKeys = const Value.absent(),
              }) => BackupVerificationsCompanion(
                id: id,
                time: time,
                stamp: stamp,
                sampled: sampled,
                ok: ok,
                failed: failed,
                failedKeys: failedKeys,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int time,
                required String stamp,
                required int sampled,
                required int ok,
                required int failed,
                required String failedKeys,
              }) => BackupVerificationsCompanion.insert(
                id: id,
                time: time,
                stamp: stamp,
                sampled: sampled,
                ok: ok,
                failed: failed,
                failedKeys: failedKeys,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupVerificationsTable, BackupVerificationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$TephraSyncDatabase,
                    $BackupVerificationsTable,
                    BackupVerificationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupVerificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraSyncDatabase,
      $BackupVerificationsTable,
      BackupVerificationRow,
      $$BackupVerificationsTableFilterComposer,
      $$BackupVerificationsTableOrderingComposer,
      $$BackupVerificationsTableAnnotationComposer,
      $$BackupVerificationsTableCreateCompanionBuilder,
      $$BackupVerificationsTableUpdateCompanionBuilder,
      (
        BackupVerificationRow,
        BaseReferences<
          _$TephraSyncDatabase,
          $BackupVerificationsTable,
          BackupVerificationRow
        >,
      ),
      BackupVerificationRow,
      PrefetchHooks Function()
    >;

class $TephraSyncDatabaseManager {
  final _$TephraSyncDatabase _db;
  $TephraSyncDatabaseManager(this._db);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$SyncedFilesTableTableManager get syncedFiles =>
      $$SyncedFilesTableTableManager(_db, _db.syncedFiles);
  $$BasesTableTableManager get bases =>
      $$BasesTableTableManager(_db, _db.bases);
  $$LocalHashCacheTableTableManager get localHashCache =>
      $$LocalHashCacheTableTableManager(_db, _db.localHashCache);
  $$RemoteEntriesTableTableManager get remoteEntries =>
      $$RemoteEntriesTableTableManager(_db, _db.remoteEntries);
  $$RemoteHeadsTableTableManager get remoteHeads =>
      $$RemoteHeadsTableTableManager(_db, _db.remoteHeads);
  $$JournalCursorsTableTableManager get journalCursors =>
      $$JournalCursorsTableTableManager(_db, _db.journalCursors);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db, _db.pendingOps);
  $$RemoteFileIdsTableTableManager get remoteFileIds =>
      $$RemoteFileIdsTableTableManager(_db, _db.remoteFileIds);
  $$BlobIndexTableTableManager get blobIndex =>
      $$BlobIndexTableTableManager(_db, _db.blobIndex);
  $$SyncLogTableTableManager get syncLog =>
      $$SyncLogTableTableManager(_db, _db.syncLog);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db, _db.conflicts);
  $$BackupsTableTableManager get backups =>
      $$BackupsTableTableManager(_db, _db.backups);
  $$BackupVerificationsTableTableManager get backupVerifications =>
      $$BackupVerificationsTableTableManager(_db, _db.backupVerifications);
}
