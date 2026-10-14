// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index_database.dart';

// ignore_for_file: type=lint
class $FilesTable extends Files with TableInfo<$FilesTable, FileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stemKeyMeta = const VerificationMeta(
    'stemKey',
  );
  @override
  late final GeneratedColumn<String> stemKey = GeneratedColumn<String>(
    'stem_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extensionMeta = const VerificationMeta(
    'extension',
  );
  @override
  late final GeneratedColumn<String> extension = GeneratedColumn<String>(
    'extension',
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
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<int> created = GeneratedColumn<int>(
    'created',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _isNoteMeta = const VerificationMeta('isNote');
  @override
  late final GeneratedColumn<bool> isNote = GeneratedColumn<bool>(
    'is_note',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_note" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    caseKey,
    nameKey,
    stemKey,
    folder,
    extension,
    size,
    mtime,
    created,
    hash,
    isNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileRow> instance, {
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
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('stem_key')) {
      context.handle(
        _stemKeyMeta,
        stemKey.isAcceptableOrUnknown(data['stem_key']!, _stemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_stemKeyMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('extension')) {
      context.handle(
        _extensionMeta,
        extension.isAcceptableOrUnknown(data['extension']!, _extensionMeta),
      );
    } else if (isInserting) {
      context.missing(_extensionMeta);
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
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('is_note')) {
      context.handle(
        _isNoteMeta,
        isNote.isAcceptableOrUnknown(data['is_note']!, _isNoteMeta),
      );
    } else if (isInserting) {
      context.missing(_isNoteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  FileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      caseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_key'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      stemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stem_key'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      extension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extension'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created'],
      ),
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      isNote: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_note'],
      )!,
    );
  }

  @override
  $FilesTable createAlias(String alias) {
    return $FilesTable(attachedDatabase, alias);
  }
}

class FileRow extends DataClass implements Insertable<FileRow> {
  /// Vault-relative path value (VaultPath.value).
  final String path;

  /// Normalized case key for case-insensitive lookup (VaultPath.caseKey).
  final String caseKey;

  /// File name in lower-case with extension ('note.md', 'image.png').
  final String nameKey;

  /// File stem in lower-case ('note').
  final String stemKey;

  /// Parent folder path, empty string for root.
  final String folder;

  /// Lower-case file extension ('md', 'png', '').
  final String extension;

  /// File size in bytes.
  final int size;

  /// Last modification timestamp in milliseconds since epoch, UTC.
  final int mtime;

  /// Creation timestamp in milliseconds since epoch, UTC (null if unavailable).
  final int? created;

  /// SHA-256 contentHash of the raw bytes.
  final String hash;

  /// True if the file is a markdown note (extension == 'md').
  final bool isNote;
  const FileRow({
    required this.path,
    required this.caseKey,
    required this.nameKey,
    required this.stemKey,
    required this.folder,
    required this.extension,
    required this.size,
    required this.mtime,
    this.created,
    required this.hash,
    required this.isNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['case_key'] = Variable<String>(caseKey);
    map['name_key'] = Variable<String>(nameKey);
    map['stem_key'] = Variable<String>(stemKey);
    map['folder'] = Variable<String>(folder);
    map['extension'] = Variable<String>(extension);
    map['size'] = Variable<int>(size);
    map['mtime'] = Variable<int>(mtime);
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<int>(created);
    }
    map['hash'] = Variable<String>(hash);
    map['is_note'] = Variable<bool>(isNote);
    return map;
  }

  FilesCompanion toCompanion(bool nullToAbsent) {
    return FilesCompanion(
      path: Value(path),
      caseKey: Value(caseKey),
      nameKey: Value(nameKey),
      stemKey: Value(stemKey),
      folder: Value(folder),
      extension: Value(extension),
      size: Value(size),
      mtime: Value(mtime),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      hash: Value(hash),
      isNote: Value(isNote),
    );
  }

  factory FileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileRow(
      path: serializer.fromJson<String>(json['path']),
      caseKey: serializer.fromJson<String>(json['caseKey']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      stemKey: serializer.fromJson<String>(json['stemKey']),
      folder: serializer.fromJson<String>(json['folder']),
      extension: serializer.fromJson<String>(json['extension']),
      size: serializer.fromJson<int>(json['size']),
      mtime: serializer.fromJson<int>(json['mtime']),
      created: serializer.fromJson<int?>(json['created']),
      hash: serializer.fromJson<String>(json['hash']),
      isNote: serializer.fromJson<bool>(json['isNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'caseKey': serializer.toJson<String>(caseKey),
      'nameKey': serializer.toJson<String>(nameKey),
      'stemKey': serializer.toJson<String>(stemKey),
      'folder': serializer.toJson<String>(folder),
      'extension': serializer.toJson<String>(extension),
      'size': serializer.toJson<int>(size),
      'mtime': serializer.toJson<int>(mtime),
      'created': serializer.toJson<int?>(created),
      'hash': serializer.toJson<String>(hash),
      'isNote': serializer.toJson<bool>(isNote),
    };
  }

  FileRow copyWith({
    String? path,
    String? caseKey,
    String? nameKey,
    String? stemKey,
    String? folder,
    String? extension,
    int? size,
    int? mtime,
    Value<int?> created = const Value.absent(),
    String? hash,
    bool? isNote,
  }) => FileRow(
    path: path ?? this.path,
    caseKey: caseKey ?? this.caseKey,
    nameKey: nameKey ?? this.nameKey,
    stemKey: stemKey ?? this.stemKey,
    folder: folder ?? this.folder,
    extension: extension ?? this.extension,
    size: size ?? this.size,
    mtime: mtime ?? this.mtime,
    created: created.present ? created.value : this.created,
    hash: hash ?? this.hash,
    isNote: isNote ?? this.isNote,
  );
  FileRow copyWithCompanion(FilesCompanion data) {
    return FileRow(
      path: data.path.present ? data.path.value : this.path,
      caseKey: data.caseKey.present ? data.caseKey.value : this.caseKey,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      stemKey: data.stemKey.present ? data.stemKey.value : this.stemKey,
      folder: data.folder.present ? data.folder.value : this.folder,
      extension: data.extension.present ? data.extension.value : this.extension,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      created: data.created.present ? data.created.value : this.created,
      hash: data.hash.present ? data.hash.value : this.hash,
      isNote: data.isNote.present ? data.isNote.value : this.isNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileRow(')
          ..write('path: $path, ')
          ..write('caseKey: $caseKey, ')
          ..write('nameKey: $nameKey, ')
          ..write('stemKey: $stemKey, ')
          ..write('folder: $folder, ')
          ..write('extension: $extension, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('created: $created, ')
          ..write('hash: $hash, ')
          ..write('isNote: $isNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    caseKey,
    nameKey,
    stemKey,
    folder,
    extension,
    size,
    mtime,
    created,
    hash,
    isNote,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileRow &&
          other.path == this.path &&
          other.caseKey == this.caseKey &&
          other.nameKey == this.nameKey &&
          other.stemKey == this.stemKey &&
          other.folder == this.folder &&
          other.extension == this.extension &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.created == this.created &&
          other.hash == this.hash &&
          other.isNote == this.isNote);
}

class FilesCompanion extends UpdateCompanion<FileRow> {
  final Value<String> path;
  final Value<String> caseKey;
  final Value<String> nameKey;
  final Value<String> stemKey;
  final Value<String> folder;
  final Value<String> extension;
  final Value<int> size;
  final Value<int> mtime;
  final Value<int?> created;
  final Value<String> hash;
  final Value<bool> isNote;
  final Value<int> rowid;
  const FilesCompanion({
    this.path = const Value.absent(),
    this.caseKey = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.stemKey = const Value.absent(),
    this.folder = const Value.absent(),
    this.extension = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.created = const Value.absent(),
    this.hash = const Value.absent(),
    this.isNote = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilesCompanion.insert({
    required String path,
    required String caseKey,
    required String nameKey,
    required String stemKey,
    required String folder,
    required String extension,
    required int size,
    required int mtime,
    this.created = const Value.absent(),
    required String hash,
    required bool isNote,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       caseKey = Value(caseKey),
       nameKey = Value(nameKey),
       stemKey = Value(stemKey),
       folder = Value(folder),
       extension = Value(extension),
       size = Value(size),
       mtime = Value(mtime),
       hash = Value(hash),
       isNote = Value(isNote);
  static Insertable<FileRow> custom({
    Expression<String>? path,
    Expression<String>? caseKey,
    Expression<String>? nameKey,
    Expression<String>? stemKey,
    Expression<String>? folder,
    Expression<String>? extension,
    Expression<int>? size,
    Expression<int>? mtime,
    Expression<int>? created,
    Expression<String>? hash,
    Expression<bool>? isNote,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (caseKey != null) 'case_key': caseKey,
      if (nameKey != null) 'name_key': nameKey,
      if (stemKey != null) 'stem_key': stemKey,
      if (folder != null) 'folder': folder,
      if (extension != null) 'extension': extension,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (created != null) 'created': created,
      if (hash != null) 'hash': hash,
      if (isNote != null) 'is_note': isNote,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilesCompanion copyWith({
    Value<String>? path,
    Value<String>? caseKey,
    Value<String>? nameKey,
    Value<String>? stemKey,
    Value<String>? folder,
    Value<String>? extension,
    Value<int>? size,
    Value<int>? mtime,
    Value<int?>? created,
    Value<String>? hash,
    Value<bool>? isNote,
    Value<int>? rowid,
  }) {
    return FilesCompanion(
      path: path ?? this.path,
      caseKey: caseKey ?? this.caseKey,
      nameKey: nameKey ?? this.nameKey,
      stemKey: stemKey ?? this.stemKey,
      folder: folder ?? this.folder,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      created: created ?? this.created,
      hash: hash ?? this.hash,
      isNote: isNote ?? this.isNote,
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
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (stemKey.present) {
      map['stem_key'] = Variable<String>(stemKey.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (extension.present) {
      map['extension'] = Variable<String>(extension.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (created.present) {
      map['created'] = Variable<int>(created.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (isNote.present) {
      map['is_note'] = Variable<bool>(isNote.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesCompanion(')
          ..write('path: $path, ')
          ..write('caseKey: $caseKey, ')
          ..write('nameKey: $nameKey, ')
          ..write('stemKey: $stemKey, ')
          ..write('folder: $folder, ')
          ..write('extension: $extension, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('created: $created, ')
          ..write('hash: $hash, ')
          ..write('isNote: $isNote, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontmatterJsonMeta = const VerificationMeta(
    'frontmatterJson',
  );
  @override
  late final GeneratedColumn<String> frontmatterJson = GeneratedColumn<String>(
    'frontmatter_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontmatterValidMeta = const VerificationMeta(
    'frontmatterValid',
  );
  @override
  late final GeneratedColumn<bool> frontmatterValid = GeneratedColumn<bool>(
    'frontmatter_valid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("frontmatter_valid" IN (0, 1))',
    ),
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    title,
    frontmatterJson,
    frontmatterValid,
    wordCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('frontmatter_json')) {
      context.handle(
        _frontmatterJsonMeta,
        frontmatterJson.isAcceptableOrUnknown(
          data['frontmatter_json']!,
          _frontmatterJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frontmatterJsonMeta);
    }
    if (data.containsKey('frontmatter_valid')) {
      context.handle(
        _frontmatterValidMeta,
        frontmatterValid.isAcceptableOrUnknown(
          data['frontmatter_valid']!,
          _frontmatterValidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frontmatterValidMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      frontmatterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frontmatter_json'],
      )!,
      frontmatterValid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}frontmatter_valid'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  /// Auto-incrementing identifier matching the FTS rowids.
  final int id;

  /// Vault path referencing [Files.path].
  final String path;

  /// File stem title.
  final String title;

  /// JSON-encoded frontmatter map ('{}' if none or invalid).
  final String frontmatterJson;

  /// True if the frontmatter was valid YAML.
  final bool frontmatterValid;

  /// Word count of the note text.
  final int wordCount;
  const NoteRow({
    required this.id,
    required this.path,
    required this.title,
    required this.frontmatterJson,
    required this.frontmatterValid,
    required this.wordCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['title'] = Variable<String>(title);
    map['frontmatter_json'] = Variable<String>(frontmatterJson);
    map['frontmatter_valid'] = Variable<bool>(frontmatterValid);
    map['word_count'] = Variable<int>(wordCount);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      path: Value(path),
      title: Value(title),
      frontmatterJson: Value(frontmatterJson),
      frontmatterValid: Value(frontmatterValid),
      wordCount: Value(wordCount),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      frontmatterJson: serializer.fromJson<String>(json['frontmatterJson']),
      frontmatterValid: serializer.fromJson<bool>(json['frontmatterValid']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String>(title),
      'frontmatterJson': serializer.toJson<String>(frontmatterJson),
      'frontmatterValid': serializer.toJson<bool>(frontmatterValid),
      'wordCount': serializer.toJson<int>(wordCount),
    };
  }

  NoteRow copyWith({
    int? id,
    String? path,
    String? title,
    String? frontmatterJson,
    bool? frontmatterValid,
    int? wordCount,
  }) => NoteRow(
    id: id ?? this.id,
    path: path ?? this.path,
    title: title ?? this.title,
    frontmatterJson: frontmatterJson ?? this.frontmatterJson,
    frontmatterValid: frontmatterValid ?? this.frontmatterValid,
    wordCount: wordCount ?? this.wordCount,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      frontmatterJson: data.frontmatterJson.present
          ? data.frontmatterJson.value
          : this.frontmatterJson,
      frontmatterValid: data.frontmatterValid.present
          ? data.frontmatterValid.value
          : this.frontmatterValid,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('frontmatterJson: $frontmatterJson, ')
          ..write('frontmatterValid: $frontmatterValid, ')
          ..write('wordCount: $wordCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    title,
    frontmatterJson,
    frontmatterValid,
    wordCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.title == this.title &&
          other.frontmatterJson == this.frontmatterJson &&
          other.frontmatterValid == this.frontmatterValid &&
          other.wordCount == this.wordCount);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> title;
  final Value<String> frontmatterJson;
  final Value<bool> frontmatterValid;
  final Value<int> wordCount;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.frontmatterJson = const Value.absent(),
    this.frontmatterValid = const Value.absent(),
    this.wordCount = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String title,
    required String frontmatterJson,
    required bool frontmatterValid,
    required int wordCount,
  }) : path = Value(path),
       title = Value(title),
       frontmatterJson = Value(frontmatterJson),
       frontmatterValid = Value(frontmatterValid),
       wordCount = Value(wordCount);
  static Insertable<NoteRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? title,
    Expression<String>? frontmatterJson,
    Expression<bool>? frontmatterValid,
    Expression<int>? wordCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (frontmatterJson != null) 'frontmatter_json': frontmatterJson,
      if (frontmatterValid != null) 'frontmatter_valid': frontmatterValid,
      if (wordCount != null) 'word_count': wordCount,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? title,
    Value<String>? frontmatterJson,
    Value<bool>? frontmatterValid,
    Value<int>? wordCount,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      frontmatterJson: frontmatterJson ?? this.frontmatterJson,
      frontmatterValid: frontmatterValid ?? this.frontmatterValid,
      wordCount: wordCount ?? this.wordCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (frontmatterJson.present) {
      map['frontmatter_json'] = Variable<String>(frontmatterJson.value);
    }
    if (frontmatterValid.present) {
      map['frontmatter_valid'] = Variable<bool>(frontmatterValid.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('frontmatterJson: $frontmatterJson, ')
          ..write('frontmatterValid: $frontmatterValid, ')
          ..write('wordCount: $wordCount')
          ..write(')'))
        .toString();
  }
}

class $AliasesTable extends Aliases with TableInfo<$AliasesTable, AliasRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasKeyMeta = const VerificationMeta(
    'aliasKey',
  );
  @override
  late final GeneratedColumn<String> aliasKey = GeneratedColumn<String>(
    'alias_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, alias, aliasKey, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<AliasRow> instance, {
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
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('alias_key')) {
      context.handle(
        _aliasKeyMeta,
        aliasKey.isAcceptableOrUnknown(data['alias_key']!, _aliasKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasKeyMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path, ordinal};
  @override
  AliasRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AliasRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      aliasKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_key'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $AliasesTable createAlias(String alias) {
    return $AliasesTable(attachedDatabase, alias);
  }
}

class AliasRow extends DataClass implements Insertable<AliasRow> {
  /// Note path referencing [Files.path].
  final String path;

  /// Original-casing alias text.
  final String alias;

  /// Lower-cased alias key.
  final String aliasKey;

  /// Position ordinal in the aliases list.
  final int ordinal;
  const AliasRow({
    required this.path,
    required this.alias,
    required this.aliasKey,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['alias'] = Variable<String>(alias);
    map['alias_key'] = Variable<String>(aliasKey);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  AliasesCompanion toCompanion(bool nullToAbsent) {
    return AliasesCompanion(
      path: Value(path),
      alias: Value(alias),
      aliasKey: Value(aliasKey),
      ordinal: Value(ordinal),
    );
  }

  factory AliasRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AliasRow(
      path: serializer.fromJson<String>(json['path']),
      alias: serializer.fromJson<String>(json['alias']),
      aliasKey: serializer.fromJson<String>(json['aliasKey']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'alias': serializer.toJson<String>(alias),
      'aliasKey': serializer.toJson<String>(aliasKey),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  AliasRow copyWith({
    String? path,
    String? alias,
    String? aliasKey,
    int? ordinal,
  }) => AliasRow(
    path: path ?? this.path,
    alias: alias ?? this.alias,
    aliasKey: aliasKey ?? this.aliasKey,
    ordinal: ordinal ?? this.ordinal,
  );
  AliasRow copyWithCompanion(AliasesCompanion data) {
    return AliasRow(
      path: data.path.present ? data.path.value : this.path,
      alias: data.alias.present ? data.alias.value : this.alias,
      aliasKey: data.aliasKey.present ? data.aliasKey.value : this.aliasKey,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AliasRow(')
          ..write('path: $path, ')
          ..write('alias: $alias, ')
          ..write('aliasKey: $aliasKey, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, alias, aliasKey, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AliasRow &&
          other.path == this.path &&
          other.alias == this.alias &&
          other.aliasKey == this.aliasKey &&
          other.ordinal == this.ordinal);
}

class AliasesCompanion extends UpdateCompanion<AliasRow> {
  final Value<String> path;
  final Value<String> alias;
  final Value<String> aliasKey;
  final Value<int> ordinal;
  final Value<int> rowid;
  const AliasesCompanion({
    this.path = const Value.absent(),
    this.alias = const Value.absent(),
    this.aliasKey = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AliasesCompanion.insert({
    required String path,
    required String alias,
    required String aliasKey,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       alias = Value(alias),
       aliasKey = Value(aliasKey),
       ordinal = Value(ordinal);
  static Insertable<AliasRow> custom({
    Expression<String>? path,
    Expression<String>? alias,
    Expression<String>? aliasKey,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (alias != null) 'alias': alias,
      if (aliasKey != null) 'alias_key': aliasKey,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AliasesCompanion copyWith({
    Value<String>? path,
    Value<String>? alias,
    Value<String>? aliasKey,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return AliasesCompanion(
      path: path ?? this.path,
      alias: alias ?? this.alias,
      aliasKey: aliasKey ?? this.aliasKey,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (aliasKey.present) {
      map['alias_key'] = Variable<String>(aliasKey.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AliasesCompanion(')
          ..write('path: $path, ')
          ..write('alias: $alias, ')
          ..write('aliasKey: $aliasKey, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeadingsTable extends Headings
    with TableInfo<$HeadingsTable, HeadingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headingTextMeta = const VerificationMeta(
    'headingText',
  );
  @override
  late final GeneratedColumn<String> headingText = GeneratedColumn<String>(
    'heading_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headingKeyMeta = const VerificationMeta(
    'headingKey',
  );
  @override
  late final GeneratedColumn<String> headingKey = GeneratedColumn<String>(
    'heading_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    ordinal,
    level,
    headingText,
    headingKey,
    startOffset,
    endOffset,
    line,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'headings';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeadingRow> instance, {
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
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('heading_text')) {
      context.handle(
        _headingTextMeta,
        headingText.isAcceptableOrUnknown(
          data['heading_text']!,
          _headingTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_headingTextMeta);
    }
    if (data.containsKey('heading_key')) {
      context.handle(
        _headingKeyMeta,
        headingKey.isAcceptableOrUnknown(data['heading_key']!, _headingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_headingKeyMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path, ordinal};
  @override
  HeadingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeadingRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      headingText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heading_text'],
      )!,
      headingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heading_key'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      )!,
    );
  }

  @override
  $HeadingsTable createAlias(String alias) {
    return $HeadingsTable(attachedDatabase, alias);
  }
}

class HeadingRow extends DataClass implements Insertable<HeadingRow> {
  /// Note path referencing [Files.path].
  final String path;

  /// 0-based order of the heading in the note.
  final int ordinal;

  /// Heading level (1..6).
  final int level;

  /// Text without '#' markers or trailing block identifiers.
  final String headingText;

  /// Normalized heading key.
  final String headingKey;

  /// Start offset in the normalized note content.
  final int startOffset;

  /// End offset in the normalized note content.
  final int endOffset;

  /// 0-based line number of the heading.
  final int line;
  const HeadingRow({
    required this.path,
    required this.ordinal,
    required this.level,
    required this.headingText,
    required this.headingKey,
    required this.startOffset,
    required this.endOffset,
    required this.line,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['ordinal'] = Variable<int>(ordinal);
    map['level'] = Variable<int>(level);
    map['heading_text'] = Variable<String>(headingText);
    map['heading_key'] = Variable<String>(headingKey);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['line'] = Variable<int>(line);
    return map;
  }

  HeadingsCompanion toCompanion(bool nullToAbsent) {
    return HeadingsCompanion(
      path: Value(path),
      ordinal: Value(ordinal),
      level: Value(level),
      headingText: Value(headingText),
      headingKey: Value(headingKey),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      line: Value(line),
    );
  }

  factory HeadingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeadingRow(
      path: serializer.fromJson<String>(json['path']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      level: serializer.fromJson<int>(json['level']),
      headingText: serializer.fromJson<String>(json['headingText']),
      headingKey: serializer.fromJson<String>(json['headingKey']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      line: serializer.fromJson<int>(json['line']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'ordinal': serializer.toJson<int>(ordinal),
      'level': serializer.toJson<int>(level),
      'headingText': serializer.toJson<String>(headingText),
      'headingKey': serializer.toJson<String>(headingKey),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'line': serializer.toJson<int>(line),
    };
  }

  HeadingRow copyWith({
    String? path,
    int? ordinal,
    int? level,
    String? headingText,
    String? headingKey,
    int? startOffset,
    int? endOffset,
    int? line,
  }) => HeadingRow(
    path: path ?? this.path,
    ordinal: ordinal ?? this.ordinal,
    level: level ?? this.level,
    headingText: headingText ?? this.headingText,
    headingKey: headingKey ?? this.headingKey,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    line: line ?? this.line,
  );
  HeadingRow copyWithCompanion(HeadingsCompanion data) {
    return HeadingRow(
      path: data.path.present ? data.path.value : this.path,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      level: data.level.present ? data.level.value : this.level,
      headingText: data.headingText.present
          ? data.headingText.value
          : this.headingText,
      headingKey: data.headingKey.present
          ? data.headingKey.value
          : this.headingKey,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      line: data.line.present ? data.line.value : this.line,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeadingRow(')
          ..write('path: $path, ')
          ..write('ordinal: $ordinal, ')
          ..write('level: $level, ')
          ..write('headingText: $headingText, ')
          ..write('headingKey: $headingKey, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    ordinal,
    level,
    headingText,
    headingKey,
    startOffset,
    endOffset,
    line,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeadingRow &&
          other.path == this.path &&
          other.ordinal == this.ordinal &&
          other.level == this.level &&
          other.headingText == this.headingText &&
          other.headingKey == this.headingKey &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.line == this.line);
}

class HeadingsCompanion extends UpdateCompanion<HeadingRow> {
  final Value<String> path;
  final Value<int> ordinal;
  final Value<int> level;
  final Value<String> headingText;
  final Value<String> headingKey;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> line;
  final Value<int> rowid;
  const HeadingsCompanion({
    this.path = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.level = const Value.absent(),
    this.headingText = const Value.absent(),
    this.headingKey = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.line = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeadingsCompanion.insert({
    required String path,
    required int ordinal,
    required int level,
    required String headingText,
    required String headingKey,
    required int startOffset,
    required int endOffset,
    required int line,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       ordinal = Value(ordinal),
       level = Value(level),
       headingText = Value(headingText),
       headingKey = Value(headingKey),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       line = Value(line);
  static Insertable<HeadingRow> custom({
    Expression<String>? path,
    Expression<int>? ordinal,
    Expression<int>? level,
    Expression<String>? headingText,
    Expression<String>? headingKey,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? line,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (ordinal != null) 'ordinal': ordinal,
      if (level != null) 'level': level,
      if (headingText != null) 'heading_text': headingText,
      if (headingKey != null) 'heading_key': headingKey,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (line != null) 'line': line,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeadingsCompanion copyWith({
    Value<String>? path,
    Value<int>? ordinal,
    Value<int>? level,
    Value<String>? headingText,
    Value<String>? headingKey,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? line,
    Value<int>? rowid,
  }) {
    return HeadingsCompanion(
      path: path ?? this.path,
      ordinal: ordinal ?? this.ordinal,
      level: level ?? this.level,
      headingText: headingText ?? this.headingText,
      headingKey: headingKey ?? this.headingKey,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      line: line ?? this.line,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (headingText.present) {
      map['heading_text'] = Variable<String>(headingText.value);
    }
    if (headingKey.present) {
      map['heading_key'] = Variable<String>(headingKey.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeadingsCompanion(')
          ..write('path: $path, ')
          ..write('ordinal: $ordinal, ')
          ..write('level: $level, ')
          ..write('headingText: $headingText, ')
          ..write('headingKey: $headingKey, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, BlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockKeyMeta = const VerificationMeta(
    'blockKey',
  );
  @override
  late final GeneratedColumn<String> blockKey = GeneratedColumn<String>(
    'block_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    blockId,
    blockKey,
    startOffset,
    endOffset,
    line,
    preview,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockRow> instance, {
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
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('block_key')) {
      context.handle(
        _blockKeyMeta,
        blockKey.isAcceptableOrUnknown(data['block_key']!, _blockKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_blockKeyMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    } else if (isInserting) {
      context.missing(_previewMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path, blockId};
  @override
  BlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      blockKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_key'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class BlockRow extends DataClass implements Insertable<BlockRow> {
  /// Note path referencing [Files.path].
  final String path;

  /// Block ID string without leading '^'.
  final String blockId;

  /// Lower-cased block ID key.
  final String blockKey;

  /// Start offset of the owning block.
  final int startOffset;

  /// End offset of the owning block.
  final int endOffset;

  /// 0-based line number.
  final int line;

  /// Short preview of the block text (single line, up to 120 chars).
  final String preview;
  const BlockRow({
    required this.path,
    required this.blockId,
    required this.blockKey,
    required this.startOffset,
    required this.endOffset,
    required this.line,
    required this.preview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['block_id'] = Variable<String>(blockId);
    map['block_key'] = Variable<String>(blockKey);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['line'] = Variable<int>(line);
    map['preview'] = Variable<String>(preview);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      path: Value(path),
      blockId: Value(blockId),
      blockKey: Value(blockKey),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      line: Value(line),
      preview: Value(preview),
    );
  }

  factory BlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockRow(
      path: serializer.fromJson<String>(json['path']),
      blockId: serializer.fromJson<String>(json['blockId']),
      blockKey: serializer.fromJson<String>(json['blockKey']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      line: serializer.fromJson<int>(json['line']),
      preview: serializer.fromJson<String>(json['preview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'blockId': serializer.toJson<String>(blockId),
      'blockKey': serializer.toJson<String>(blockKey),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'line': serializer.toJson<int>(line),
      'preview': serializer.toJson<String>(preview),
    };
  }

  BlockRow copyWith({
    String? path,
    String? blockId,
    String? blockKey,
    int? startOffset,
    int? endOffset,
    int? line,
    String? preview,
  }) => BlockRow(
    path: path ?? this.path,
    blockId: blockId ?? this.blockId,
    blockKey: blockKey ?? this.blockKey,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    line: line ?? this.line,
    preview: preview ?? this.preview,
  );
  BlockRow copyWithCompanion(BlocksCompanion data) {
    return BlockRow(
      path: data.path.present ? data.path.value : this.path,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      blockKey: data.blockKey.present ? data.blockKey.value : this.blockKey,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      line: data.line.present ? data.line.value : this.line,
      preview: data.preview.present ? data.preview.value : this.preview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockRow(')
          ..write('path: $path, ')
          ..write('blockId: $blockId, ')
          ..write('blockKey: $blockKey, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line, ')
          ..write('preview: $preview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    blockId,
    blockKey,
    startOffset,
    endOffset,
    line,
    preview,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockRow &&
          other.path == this.path &&
          other.blockId == this.blockId &&
          other.blockKey == this.blockKey &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.line == this.line &&
          other.preview == this.preview);
}

class BlocksCompanion extends UpdateCompanion<BlockRow> {
  final Value<String> path;
  final Value<String> blockId;
  final Value<String> blockKey;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> line;
  final Value<String> preview;
  final Value<int> rowid;
  const BlocksCompanion({
    this.path = const Value.absent(),
    this.blockId = const Value.absent(),
    this.blockKey = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.line = const Value.absent(),
    this.preview = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String path,
    required String blockId,
    required String blockKey,
    required int startOffset,
    required int endOffset,
    required int line,
    required String preview,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       blockId = Value(blockId),
       blockKey = Value(blockKey),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       line = Value(line),
       preview = Value(preview);
  static Insertable<BlockRow> custom({
    Expression<String>? path,
    Expression<String>? blockId,
    Expression<String>? blockKey,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? line,
    Expression<String>? preview,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (blockId != null) 'block_id': blockId,
      if (blockKey != null) 'block_key': blockKey,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (line != null) 'line': line,
      if (preview != null) 'preview': preview,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith({
    Value<String>? path,
    Value<String>? blockId,
    Value<String>? blockKey,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? line,
    Value<String>? preview,
    Value<int>? rowid,
  }) {
    return BlocksCompanion(
      path: path ?? this.path,
      blockId: blockId ?? this.blockId,
      blockKey: blockKey ?? this.blockKey,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      line: line ?? this.line,
      preview: preview ?? this.preview,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (blockKey.present) {
      map['block_key'] = Variable<String>(blockKey.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('path: $path, ')
          ..write('blockId: $blockId, ')
          ..write('blockKey: $blockKey, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line, ')
          ..write('preview: $preview, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LinksTable extends Links with TableInfo<$LinksTable, LinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetRawMeta = const VerificationMeta(
    'targetRaw',
  );
  @override
  late final GeneratedColumn<String> targetRaw = GeneratedColumn<String>(
    'target_raw',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKeyMeta = const VerificationMeta(
    'targetKey',
  );
  @override
  late final GeneratedColumn<String> targetKey = GeneratedColumn<String>(
    'target_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _syntaxMeta = const VerificationMeta('syntax');
  @override
  late final GeneratedColumn<String> syntax = GeneratedColumn<String>(
    'syntax',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headingMeta = const VerificationMeta(
    'heading',
  );
  @override
  late final GeneratedColumn<String> heading = GeneratedColumn<String>(
    'heading',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockRefMeta = const VerificationMeta(
    'blockRef',
  );
  @override
  late final GeneratedColumn<String> blockRef = GeneratedColumn<String>(
    'block_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _embedSizeMeta = const VerificationMeta(
    'embedSize',
  );
  @override
  late final GeneratedColumn<String> embedSize = GeneratedColumn<String>(
    'embed_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedMeta = const VerificationMeta(
    'resolved',
  );
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
    'resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resolved" IN (0, 1))',
    ),
  );
  static const VerificationMeta _viaAliasMeta = const VerificationMeta(
    'viaAlias',
  );
  @override
  late final GeneratedColumn<bool> viaAlias = GeneratedColumn<bool>(
    'via_alias',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("via_alias" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    targetRaw,
    targetKey,
    targetPath,
    kind,
    syntax,
    heading,
    blockRef,
    alias,
    embedSize,
    startOffset,
    endOffset,
    line,
    resolved,
    viaAlias,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'links';
  @override
  VerificationContext validateIntegrity(
    Insertable<LinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('target_raw')) {
      context.handle(
        _targetRawMeta,
        targetRaw.isAcceptableOrUnknown(data['target_raw']!, _targetRawMeta),
      );
    } else if (isInserting) {
      context.missing(_targetRawMeta);
    }
    if (data.containsKey('target_key')) {
      context.handle(
        _targetKeyMeta,
        targetKey.isAcceptableOrUnknown(data['target_key']!, _targetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKeyMeta);
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('syntax')) {
      context.handle(
        _syntaxMeta,
        syntax.isAcceptableOrUnknown(data['syntax']!, _syntaxMeta),
      );
    } else if (isInserting) {
      context.missing(_syntaxMeta);
    }
    if (data.containsKey('heading')) {
      context.handle(
        _headingMeta,
        heading.isAcceptableOrUnknown(data['heading']!, _headingMeta),
      );
    }
    if (data.containsKey('block_ref')) {
      context.handle(
        _blockRefMeta,
        blockRef.isAcceptableOrUnknown(data['block_ref']!, _blockRefMeta),
      );
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('embed_size')) {
      context.handle(
        _embedSizeMeta,
        embedSize.isAcceptableOrUnknown(data['embed_size']!, _embedSizeMeta),
      );
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    if (data.containsKey('resolved')) {
      context.handle(
        _resolvedMeta,
        resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta),
      );
    } else if (isInserting) {
      context.missing(_resolvedMeta);
    }
    if (data.containsKey('via_alias')) {
      context.handle(
        _viaAliasMeta,
        viaAlias.isAcceptableOrUnknown(data['via_alias']!, _viaAliasMeta),
      );
    } else if (isInserting) {
      context.missing(_viaAliasMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      targetRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_raw'],
      )!,
      targetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_key'],
      )!,
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      syntax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}syntax'],
      )!,
      heading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heading'],
      ),
      blockRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_ref'],
      ),
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
      embedSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embed_size'],
      ),
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      )!,
      resolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resolved'],
      )!,
      viaAlias: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}via_alias'],
      )!,
    );
  }

  @override
  $LinksTable createAlias(String alias) {
    return $LinksTable(attachedDatabase, alias);
  }
}

class LinkRow extends DataClass implements Insertable<LinkRow> {
  /// Unique link row ID.
  final int id;

  /// Source note path referencing [Files.path].
  final String source;

  /// Target string as written without subpath or alias.
  final String targetRaw;

  /// Link target lookup key.
  final String targetKey;

  /// Resolved target vault path value (null if unresolved).
  final String? targetPath;

  /// Kind: 'link' or 'embed'.
  final String kind;

  /// Syntax: 'wiki' or 'markdown'.
  final String syntax;

  /// Target heading path chain ('H1#H2') if present.
  final String? heading;

  /// Target block reference ID without '^' if present.
  final String? blockRef;

  /// Display text alias.
  final String? alias;

  /// Embed dimensions string ('300' or '300x200').
  final String? embedSize;

  /// Start offset including '!' for embeds.
  final int startOffset;

  /// End offset.
  final int endOffset;

  /// Line number.
  final int line;

  /// True if resolved to a vault file.
  final bool resolved;

  /// True if resolved via a note's frontmatter alias.
  final bool viaAlias;
  const LinkRow({
    required this.id,
    required this.source,
    required this.targetRaw,
    required this.targetKey,
    this.targetPath,
    required this.kind,
    required this.syntax,
    this.heading,
    this.blockRef,
    this.alias,
    this.embedSize,
    required this.startOffset,
    required this.endOffset,
    required this.line,
    required this.resolved,
    required this.viaAlias,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['target_raw'] = Variable<String>(targetRaw);
    map['target_key'] = Variable<String>(targetKey);
    if (!nullToAbsent || targetPath != null) {
      map['target_path'] = Variable<String>(targetPath);
    }
    map['kind'] = Variable<String>(kind);
    map['syntax'] = Variable<String>(syntax);
    if (!nullToAbsent || heading != null) {
      map['heading'] = Variable<String>(heading);
    }
    if (!nullToAbsent || blockRef != null) {
      map['block_ref'] = Variable<String>(blockRef);
    }
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    if (!nullToAbsent || embedSize != null) {
      map['embed_size'] = Variable<String>(embedSize);
    }
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['line'] = Variable<int>(line);
    map['resolved'] = Variable<bool>(resolved);
    map['via_alias'] = Variable<bool>(viaAlias);
    return map;
  }

  LinksCompanion toCompanion(bool nullToAbsent) {
    return LinksCompanion(
      id: Value(id),
      source: Value(source),
      targetRaw: Value(targetRaw),
      targetKey: Value(targetKey),
      targetPath: targetPath == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPath),
      kind: Value(kind),
      syntax: Value(syntax),
      heading: heading == null && nullToAbsent
          ? const Value.absent()
          : Value(heading),
      blockRef: blockRef == null && nullToAbsent
          ? const Value.absent()
          : Value(blockRef),
      alias: alias == null && nullToAbsent
          ? const Value.absent()
          : Value(alias),
      embedSize: embedSize == null && nullToAbsent
          ? const Value.absent()
          : Value(embedSize),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      line: Value(line),
      resolved: Value(resolved),
      viaAlias: Value(viaAlias),
    );
  }

  factory LinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      targetRaw: serializer.fromJson<String>(json['targetRaw']),
      targetKey: serializer.fromJson<String>(json['targetKey']),
      targetPath: serializer.fromJson<String?>(json['targetPath']),
      kind: serializer.fromJson<String>(json['kind']),
      syntax: serializer.fromJson<String>(json['syntax']),
      heading: serializer.fromJson<String?>(json['heading']),
      blockRef: serializer.fromJson<String?>(json['blockRef']),
      alias: serializer.fromJson<String?>(json['alias']),
      embedSize: serializer.fromJson<String?>(json['embedSize']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      line: serializer.fromJson<int>(json['line']),
      resolved: serializer.fromJson<bool>(json['resolved']),
      viaAlias: serializer.fromJson<bool>(json['viaAlias']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'targetRaw': serializer.toJson<String>(targetRaw),
      'targetKey': serializer.toJson<String>(targetKey),
      'targetPath': serializer.toJson<String?>(targetPath),
      'kind': serializer.toJson<String>(kind),
      'syntax': serializer.toJson<String>(syntax),
      'heading': serializer.toJson<String?>(heading),
      'blockRef': serializer.toJson<String?>(blockRef),
      'alias': serializer.toJson<String?>(alias),
      'embedSize': serializer.toJson<String?>(embedSize),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'line': serializer.toJson<int>(line),
      'resolved': serializer.toJson<bool>(resolved),
      'viaAlias': serializer.toJson<bool>(viaAlias),
    };
  }

  LinkRow copyWith({
    int? id,
    String? source,
    String? targetRaw,
    String? targetKey,
    Value<String?> targetPath = const Value.absent(),
    String? kind,
    String? syntax,
    Value<String?> heading = const Value.absent(),
    Value<String?> blockRef = const Value.absent(),
    Value<String?> alias = const Value.absent(),
    Value<String?> embedSize = const Value.absent(),
    int? startOffset,
    int? endOffset,
    int? line,
    bool? resolved,
    bool? viaAlias,
  }) => LinkRow(
    id: id ?? this.id,
    source: source ?? this.source,
    targetRaw: targetRaw ?? this.targetRaw,
    targetKey: targetKey ?? this.targetKey,
    targetPath: targetPath.present ? targetPath.value : this.targetPath,
    kind: kind ?? this.kind,
    syntax: syntax ?? this.syntax,
    heading: heading.present ? heading.value : this.heading,
    blockRef: blockRef.present ? blockRef.value : this.blockRef,
    alias: alias.present ? alias.value : this.alias,
    embedSize: embedSize.present ? embedSize.value : this.embedSize,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    line: line ?? this.line,
    resolved: resolved ?? this.resolved,
    viaAlias: viaAlias ?? this.viaAlias,
  );
  LinkRow copyWithCompanion(LinksCompanion data) {
    return LinkRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      targetRaw: data.targetRaw.present ? data.targetRaw.value : this.targetRaw,
      targetKey: data.targetKey.present ? data.targetKey.value : this.targetKey,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      kind: data.kind.present ? data.kind.value : this.kind,
      syntax: data.syntax.present ? data.syntax.value : this.syntax,
      heading: data.heading.present ? data.heading.value : this.heading,
      blockRef: data.blockRef.present ? data.blockRef.value : this.blockRef,
      alias: data.alias.present ? data.alias.value : this.alias,
      embedSize: data.embedSize.present ? data.embedSize.value : this.embedSize,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      line: data.line.present ? data.line.value : this.line,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
      viaAlias: data.viaAlias.present ? data.viaAlias.value : this.viaAlias,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('targetRaw: $targetRaw, ')
          ..write('targetKey: $targetKey, ')
          ..write('targetPath: $targetPath, ')
          ..write('kind: $kind, ')
          ..write('syntax: $syntax, ')
          ..write('heading: $heading, ')
          ..write('blockRef: $blockRef, ')
          ..write('alias: $alias, ')
          ..write('embedSize: $embedSize, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line, ')
          ..write('resolved: $resolved, ')
          ..write('viaAlias: $viaAlias')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    targetRaw,
    targetKey,
    targetPath,
    kind,
    syntax,
    heading,
    blockRef,
    alias,
    embedSize,
    startOffset,
    endOffset,
    line,
    resolved,
    viaAlias,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.targetRaw == this.targetRaw &&
          other.targetKey == this.targetKey &&
          other.targetPath == this.targetPath &&
          other.kind == this.kind &&
          other.syntax == this.syntax &&
          other.heading == this.heading &&
          other.blockRef == this.blockRef &&
          other.alias == this.alias &&
          other.embedSize == this.embedSize &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.line == this.line &&
          other.resolved == this.resolved &&
          other.viaAlias == this.viaAlias);
}

class LinksCompanion extends UpdateCompanion<LinkRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> targetRaw;
  final Value<String> targetKey;
  final Value<String?> targetPath;
  final Value<String> kind;
  final Value<String> syntax;
  final Value<String?> heading;
  final Value<String?> blockRef;
  final Value<String?> alias;
  final Value<String?> embedSize;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> line;
  final Value<bool> resolved;
  final Value<bool> viaAlias;
  const LinksCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.targetRaw = const Value.absent(),
    this.targetKey = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.kind = const Value.absent(),
    this.syntax = const Value.absent(),
    this.heading = const Value.absent(),
    this.blockRef = const Value.absent(),
    this.alias = const Value.absent(),
    this.embedSize = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.line = const Value.absent(),
    this.resolved = const Value.absent(),
    this.viaAlias = const Value.absent(),
  });
  LinksCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String targetRaw,
    required String targetKey,
    this.targetPath = const Value.absent(),
    required String kind,
    required String syntax,
    this.heading = const Value.absent(),
    this.blockRef = const Value.absent(),
    this.alias = const Value.absent(),
    this.embedSize = const Value.absent(),
    required int startOffset,
    required int endOffset,
    required int line,
    required bool resolved,
    required bool viaAlias,
  }) : source = Value(source),
       targetRaw = Value(targetRaw),
       targetKey = Value(targetKey),
       kind = Value(kind),
       syntax = Value(syntax),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       line = Value(line),
       resolved = Value(resolved),
       viaAlias = Value(viaAlias);
  static Insertable<LinkRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? targetRaw,
    Expression<String>? targetKey,
    Expression<String>? targetPath,
    Expression<String>? kind,
    Expression<String>? syntax,
    Expression<String>? heading,
    Expression<String>? blockRef,
    Expression<String>? alias,
    Expression<String>? embedSize,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? line,
    Expression<bool>? resolved,
    Expression<bool>? viaAlias,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (targetRaw != null) 'target_raw': targetRaw,
      if (targetKey != null) 'target_key': targetKey,
      if (targetPath != null) 'target_path': targetPath,
      if (kind != null) 'kind': kind,
      if (syntax != null) 'syntax': syntax,
      if (heading != null) 'heading': heading,
      if (blockRef != null) 'block_ref': blockRef,
      if (alias != null) 'alias': alias,
      if (embedSize != null) 'embed_size': embedSize,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (line != null) 'line': line,
      if (resolved != null) 'resolved': resolved,
      if (viaAlias != null) 'via_alias': viaAlias,
    });
  }

  LinksCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? targetRaw,
    Value<String>? targetKey,
    Value<String?>? targetPath,
    Value<String>? kind,
    Value<String>? syntax,
    Value<String?>? heading,
    Value<String?>? blockRef,
    Value<String?>? alias,
    Value<String?>? embedSize,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? line,
    Value<bool>? resolved,
    Value<bool>? viaAlias,
  }) {
    return LinksCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      targetRaw: targetRaw ?? this.targetRaw,
      targetKey: targetKey ?? this.targetKey,
      targetPath: targetPath ?? this.targetPath,
      kind: kind ?? this.kind,
      syntax: syntax ?? this.syntax,
      heading: heading ?? this.heading,
      blockRef: blockRef ?? this.blockRef,
      alias: alias ?? this.alias,
      embedSize: embedSize ?? this.embedSize,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      line: line ?? this.line,
      resolved: resolved ?? this.resolved,
      viaAlias: viaAlias ?? this.viaAlias,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (targetRaw.present) {
      map['target_raw'] = Variable<String>(targetRaw.value);
    }
    if (targetKey.present) {
      map['target_key'] = Variable<String>(targetKey.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (syntax.present) {
      map['syntax'] = Variable<String>(syntax.value);
    }
    if (heading.present) {
      map['heading'] = Variable<String>(heading.value);
    }
    if (blockRef.present) {
      map['block_ref'] = Variable<String>(blockRef.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (embedSize.present) {
      map['embed_size'] = Variable<String>(embedSize.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    if (viaAlias.present) {
      map['via_alias'] = Variable<bool>(viaAlias.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinksCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('targetRaw: $targetRaw, ')
          ..write('targetKey: $targetKey, ')
          ..write('targetPath: $targetPath, ')
          ..write('kind: $kind, ')
          ..write('syntax: $syntax, ')
          ..write('heading: $heading, ')
          ..write('blockRef: $blockRef, ')
          ..write('alias: $alias, ')
          ..write('embedSize: $embedSize, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('line: $line, ')
          ..write('resolved: $resolved, ')
          ..write('viaAlias: $viaAlias')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagLowerMeta = const VerificationMeta(
    'tagLower',
  );
  @override
  late final GeneratedColumn<String> tagLower = GeneratedColumn<String>(
    'tag_lower',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    tag,
    tagLower,
    startOffset,
    line,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('tag_lower')) {
      context.handle(
        _tagLowerMeta,
        tagLower.isAcceptableOrUnknown(data['tag_lower']!, _tagLowerMeta),
      );
    } else if (isInserting) {
      context.missing(_tagLowerMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      tagLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_lower'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      ),
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  /// Unique tag row ID.
  final int id;

  /// Note path referencing [Files.path].
  final String path;

  /// Tag string without '#', original case.
  final String tag;

  /// Lower-case tag string.
  final String tagLower;

  /// Start offset in content (null for frontmatter tags).
  final int? startOffset;

  /// Line number in content (null for frontmatter tags).
  final int? line;
  const TagRow({
    required this.id,
    required this.path,
    required this.tag,
    required this.tagLower,
    this.startOffset,
    this.line,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['tag'] = Variable<String>(tag);
    map['tag_lower'] = Variable<String>(tagLower);
    if (!nullToAbsent || startOffset != null) {
      map['start_offset'] = Variable<int>(startOffset);
    }
    if (!nullToAbsent || line != null) {
      map['line'] = Variable<int>(line);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      path: Value(path),
      tag: Value(tag),
      tagLower: Value(tagLower),
      startOffset: startOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(startOffset),
      line: line == null && nullToAbsent ? const Value.absent() : Value(line),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      tag: serializer.fromJson<String>(json['tag']),
      tagLower: serializer.fromJson<String>(json['tagLower']),
      startOffset: serializer.fromJson<int?>(json['startOffset']),
      line: serializer.fromJson<int?>(json['line']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'tag': serializer.toJson<String>(tag),
      'tagLower': serializer.toJson<String>(tagLower),
      'startOffset': serializer.toJson<int?>(startOffset),
      'line': serializer.toJson<int?>(line),
    };
  }

  TagRow copyWith({
    int? id,
    String? path,
    String? tag,
    String? tagLower,
    Value<int?> startOffset = const Value.absent(),
    Value<int?> line = const Value.absent(),
  }) => TagRow(
    id: id ?? this.id,
    path: path ?? this.path,
    tag: tag ?? this.tag,
    tagLower: tagLower ?? this.tagLower,
    startOffset: startOffset.present ? startOffset.value : this.startOffset,
    line: line.present ? line.value : this.line,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      tag: data.tag.present ? data.tag.value : this.tag,
      tagLower: data.tagLower.present ? data.tagLower.value : this.tagLower,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      line: data.line.present ? data.line.value : this.line,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('tag: $tag, ')
          ..write('tagLower: $tagLower, ')
          ..write('startOffset: $startOffset, ')
          ..write('line: $line')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, tag, tagLower, startOffset, line);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.tag == this.tag &&
          other.tagLower == this.tagLower &&
          other.startOffset == this.startOffset &&
          other.line == this.line);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> tag;
  final Value<String> tagLower;
  final Value<int?> startOffset;
  final Value<int?> line;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.tag = const Value.absent(),
    this.tagLower = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.line = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String tag,
    required String tagLower,
    this.startOffset = const Value.absent(),
    this.line = const Value.absent(),
  }) : path = Value(path),
       tag = Value(tag),
       tagLower = Value(tagLower);
  static Insertable<TagRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? tag,
    Expression<String>? tagLower,
    Expression<int>? startOffset,
    Expression<int>? line,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (tag != null) 'tag': tag,
      if (tagLower != null) 'tag_lower': tagLower,
      if (startOffset != null) 'start_offset': startOffset,
      if (line != null) 'line': line,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? tag,
    Value<String>? tagLower,
    Value<int?>? startOffset,
    Value<int?>? line,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      tag: tag ?? this.tag,
      tagLower: tagLower ?? this.tagLower,
      startOffset: startOffset ?? this.startOffset,
      line: line ?? this.line,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (tagLower.present) {
      map['tag_lower'] = Variable<String>(tagLower.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('tag: $tag, ')
          ..write('tagLower: $tagLower, ')
          ..write('startOffset: $startOffset, ')
          ..write('line: $line')
          ..write(')'))
        .toString();
  }
}

class $PropertiesTable extends Properties
    with TableInfo<$PropertiesTable, PropertyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropertiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyLowerMeta = const VerificationMeta(
    'keyLower',
  );
  @override
  late final GeneratedColumn<String> keyLower = GeneratedColumn<String>(
    'key_lower',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTextMeta = const VerificationMeta(
    'valueText',
  );
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
    'value_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueLowerMeta = const VerificationMeta(
    'valueLower',
  );
  @override
  late final GeneratedColumn<String> valueLower = GeneratedColumn<String>(
    'value_lower',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueNumMeta = const VerificationMeta(
    'valueNum',
  );
  @override
  late final GeneratedColumn<double> valueNum = GeneratedColumn<double>(
    'value_num',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueBoolMeta = const VerificationMeta(
    'valueBool',
  );
  @override
  late final GeneratedColumn<bool> valueBool = GeneratedColumn<bool>(
    'value_bool',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("value_bool" IN (0, 1))',
    ),
  );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<String> valueDate = GeneratedColumn<String>(
    'value_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    key,
    keyLower,
    valueType,
    ordinal,
    valueText,
    valueLower,
    valueNum,
    valueBool,
    valueDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'properties';
  @override
  VerificationContext validateIntegrity(
    Insertable<PropertyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('key_lower')) {
      context.handle(
        _keyLowerMeta,
        keyLower.isAcceptableOrUnknown(data['key_lower']!, _keyLowerMeta),
      );
    } else if (isInserting) {
      context.missing(_keyLowerMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(
        _valueTextMeta,
        valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta),
      );
    }
    if (data.containsKey('value_lower')) {
      context.handle(
        _valueLowerMeta,
        valueLower.isAcceptableOrUnknown(data['value_lower']!, _valueLowerMeta),
      );
    }
    if (data.containsKey('value_num')) {
      context.handle(
        _valueNumMeta,
        valueNum.isAcceptableOrUnknown(data['value_num']!, _valueNumMeta),
      );
    }
    if (data.containsKey('value_bool')) {
      context.handle(
        _valueBoolMeta,
        valueBool.isAcceptableOrUnknown(data['value_bool']!, _valueBoolMeta),
      );
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PropertyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PropertyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      keyLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_lower'],
      )!,
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      valueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_text'],
      ),
      valueLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_lower'],
      ),
      valueNum: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value_num'],
      ),
      valueBool: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}value_bool'],
      ),
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_date'],
      ),
    );
  }

  @override
  $PropertiesTable createAlias(String alias) {
    return $PropertiesTable(attachedDatabase, alias);
  }
}

class PropertyRow extends DataClass implements Insertable<PropertyRow> {
  /// Unique property row ID.
  final int id;

  /// Note path referencing [Files.path].
  final String path;

  /// Property key in original case.
  final String key;

  /// Lower-case property key.
  final String keyLower;

  /// Inferred type: text|multitext|number|checkbox|date|datetime|aliases|tags.
  final String valueType;

  /// List element index (0 for scalar properties).
  final int ordinal;

  /// String value representation (null for null values or empty lists).
  final String? valueText;

  /// Lower-case string value.
  final String? valueLower;

  /// Numeric representation if numeric.
  final double? valueNum;

  /// Boolean representation if boolean.
  final bool? valueBool;

  /// Formatted date/datetime string if date/datetime.
  final String? valueDate;
  const PropertyRow({
    required this.id,
    required this.path,
    required this.key,
    required this.keyLower,
    required this.valueType,
    required this.ordinal,
    this.valueText,
    this.valueLower,
    this.valueNum,
    this.valueBool,
    this.valueDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['key'] = Variable<String>(key);
    map['key_lower'] = Variable<String>(keyLower);
    map['value_type'] = Variable<String>(valueType);
    map['ordinal'] = Variable<int>(ordinal);
    if (!nullToAbsent || valueText != null) {
      map['value_text'] = Variable<String>(valueText);
    }
    if (!nullToAbsent || valueLower != null) {
      map['value_lower'] = Variable<String>(valueLower);
    }
    if (!nullToAbsent || valueNum != null) {
      map['value_num'] = Variable<double>(valueNum);
    }
    if (!nullToAbsent || valueBool != null) {
      map['value_bool'] = Variable<bool>(valueBool);
    }
    if (!nullToAbsent || valueDate != null) {
      map['value_date'] = Variable<String>(valueDate);
    }
    return map;
  }

  PropertiesCompanion toCompanion(bool nullToAbsent) {
    return PropertiesCompanion(
      id: Value(id),
      path: Value(path),
      key: Value(key),
      keyLower: Value(keyLower),
      valueType: Value(valueType),
      ordinal: Value(ordinal),
      valueText: valueText == null && nullToAbsent
          ? const Value.absent()
          : Value(valueText),
      valueLower: valueLower == null && nullToAbsent
          ? const Value.absent()
          : Value(valueLower),
      valueNum: valueNum == null && nullToAbsent
          ? const Value.absent()
          : Value(valueNum),
      valueBool: valueBool == null && nullToAbsent
          ? const Value.absent()
          : Value(valueBool),
      valueDate: valueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(valueDate),
    );
  }

  factory PropertyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PropertyRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      key: serializer.fromJson<String>(json['key']),
      keyLower: serializer.fromJson<String>(json['keyLower']),
      valueType: serializer.fromJson<String>(json['valueType']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      valueText: serializer.fromJson<String?>(json['valueText']),
      valueLower: serializer.fromJson<String?>(json['valueLower']),
      valueNum: serializer.fromJson<double?>(json['valueNum']),
      valueBool: serializer.fromJson<bool?>(json['valueBool']),
      valueDate: serializer.fromJson<String?>(json['valueDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'key': serializer.toJson<String>(key),
      'keyLower': serializer.toJson<String>(keyLower),
      'valueType': serializer.toJson<String>(valueType),
      'ordinal': serializer.toJson<int>(ordinal),
      'valueText': serializer.toJson<String?>(valueText),
      'valueLower': serializer.toJson<String?>(valueLower),
      'valueNum': serializer.toJson<double?>(valueNum),
      'valueBool': serializer.toJson<bool?>(valueBool),
      'valueDate': serializer.toJson<String?>(valueDate),
    };
  }

  PropertyRow copyWith({
    int? id,
    String? path,
    String? key,
    String? keyLower,
    String? valueType,
    int? ordinal,
    Value<String?> valueText = const Value.absent(),
    Value<String?> valueLower = const Value.absent(),
    Value<double?> valueNum = const Value.absent(),
    Value<bool?> valueBool = const Value.absent(),
    Value<String?> valueDate = const Value.absent(),
  }) => PropertyRow(
    id: id ?? this.id,
    path: path ?? this.path,
    key: key ?? this.key,
    keyLower: keyLower ?? this.keyLower,
    valueType: valueType ?? this.valueType,
    ordinal: ordinal ?? this.ordinal,
    valueText: valueText.present ? valueText.value : this.valueText,
    valueLower: valueLower.present ? valueLower.value : this.valueLower,
    valueNum: valueNum.present ? valueNum.value : this.valueNum,
    valueBool: valueBool.present ? valueBool.value : this.valueBool,
    valueDate: valueDate.present ? valueDate.value : this.valueDate,
  );
  PropertyRow copyWithCompanion(PropertiesCompanion data) {
    return PropertyRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      key: data.key.present ? data.key.value : this.key,
      keyLower: data.keyLower.present ? data.keyLower.value : this.keyLower,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
      valueLower: data.valueLower.present
          ? data.valueLower.value
          : this.valueLower,
      valueNum: data.valueNum.present ? data.valueNum.value : this.valueNum,
      valueBool: data.valueBool.present ? data.valueBool.value : this.valueBool,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PropertyRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('key: $key, ')
          ..write('keyLower: $keyLower, ')
          ..write('valueType: $valueType, ')
          ..write('ordinal: $ordinal, ')
          ..write('valueText: $valueText, ')
          ..write('valueLower: $valueLower, ')
          ..write('valueNum: $valueNum, ')
          ..write('valueBool: $valueBool, ')
          ..write('valueDate: $valueDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    key,
    keyLower,
    valueType,
    ordinal,
    valueText,
    valueLower,
    valueNum,
    valueBool,
    valueDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.key == this.key &&
          other.keyLower == this.keyLower &&
          other.valueType == this.valueType &&
          other.ordinal == this.ordinal &&
          other.valueText == this.valueText &&
          other.valueLower == this.valueLower &&
          other.valueNum == this.valueNum &&
          other.valueBool == this.valueBool &&
          other.valueDate == this.valueDate);
}

class PropertiesCompanion extends UpdateCompanion<PropertyRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> key;
  final Value<String> keyLower;
  final Value<String> valueType;
  final Value<int> ordinal;
  final Value<String?> valueText;
  final Value<String?> valueLower;
  final Value<double?> valueNum;
  final Value<bool?> valueBool;
  final Value<String?> valueDate;
  const PropertiesCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.key = const Value.absent(),
    this.keyLower = const Value.absent(),
    this.valueType = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.valueText = const Value.absent(),
    this.valueLower = const Value.absent(),
    this.valueNum = const Value.absent(),
    this.valueBool = const Value.absent(),
    this.valueDate = const Value.absent(),
  });
  PropertiesCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String key,
    required String keyLower,
    required String valueType,
    required int ordinal,
    this.valueText = const Value.absent(),
    this.valueLower = const Value.absent(),
    this.valueNum = const Value.absent(),
    this.valueBool = const Value.absent(),
    this.valueDate = const Value.absent(),
  }) : path = Value(path),
       key = Value(key),
       keyLower = Value(keyLower),
       valueType = Value(valueType),
       ordinal = Value(ordinal);
  static Insertable<PropertyRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? key,
    Expression<String>? keyLower,
    Expression<String>? valueType,
    Expression<int>? ordinal,
    Expression<String>? valueText,
    Expression<String>? valueLower,
    Expression<double>? valueNum,
    Expression<bool>? valueBool,
    Expression<String>? valueDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (key != null) 'key': key,
      if (keyLower != null) 'key_lower': keyLower,
      if (valueType != null) 'value_type': valueType,
      if (ordinal != null) 'ordinal': ordinal,
      if (valueText != null) 'value_text': valueText,
      if (valueLower != null) 'value_lower': valueLower,
      if (valueNum != null) 'value_num': valueNum,
      if (valueBool != null) 'value_bool': valueBool,
      if (valueDate != null) 'value_date': valueDate,
    });
  }

  PropertiesCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? key,
    Value<String>? keyLower,
    Value<String>? valueType,
    Value<int>? ordinal,
    Value<String?>? valueText,
    Value<String?>? valueLower,
    Value<double?>? valueNum,
    Value<bool?>? valueBool,
    Value<String?>? valueDate,
  }) {
    return PropertiesCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      key: key ?? this.key,
      keyLower: keyLower ?? this.keyLower,
      valueType: valueType ?? this.valueType,
      ordinal: ordinal ?? this.ordinal,
      valueText: valueText ?? this.valueText,
      valueLower: valueLower ?? this.valueLower,
      valueNum: valueNum ?? this.valueNum,
      valueBool: valueBool ?? this.valueBool,
      valueDate: valueDate ?? this.valueDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (keyLower.present) {
      map['key_lower'] = Variable<String>(keyLower.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (valueLower.present) {
      map['value_lower'] = Variable<String>(valueLower.value);
    }
    if (valueNum.present) {
      map['value_num'] = Variable<double>(valueNum.value);
    }
    if (valueBool.present) {
      map['value_bool'] = Variable<bool>(valueBool.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<String>(valueDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropertiesCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('key: $key, ')
          ..write('keyLower: $keyLower, ')
          ..write('valueType: $valueType, ')
          ..write('ordinal: $ordinal, ')
          ..write('valueText: $valueText, ')
          ..write('valueLower: $valueLower, ')
          ..write('valueNum: $valueNum, ')
          ..write('valueBool: $valueBool, ')
          ..write('valueDate: $valueDate')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES files (path) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusCharMeta = const VerificationMeta(
    'statusChar',
  );
  @override
  late final GeneratedColumn<String> statusChar = GeneratedColumn<String>(
    'status_char',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTextMeta = const VerificationMeta(
    'taskText',
  );
  @override
  late final GeneratedColumn<String> taskText = GeneratedColumn<String>(
    'task_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskLowerMeta = const VerificationMeta(
    'taskLower',
  );
  @override
  late final GeneratedColumn<String> taskLower = GeneratedColumn<String>(
    'task_lower',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<String> due = GeneratedColumn<String>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    line,
    statusChar,
    taskText,
    taskLower,
    startOffset,
    endOffset,
    due,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    if (data.containsKey('status_char')) {
      context.handle(
        _statusCharMeta,
        statusChar.isAcceptableOrUnknown(data['status_char']!, _statusCharMeta),
      );
    } else if (isInserting) {
      context.missing(_statusCharMeta);
    }
    if (data.containsKey('task_text')) {
      context.handle(
        _taskTextMeta,
        taskText.isAcceptableOrUnknown(data['task_text']!, _taskTextMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTextMeta);
    }
    if (data.containsKey('task_lower')) {
      context.handle(
        _taskLowerMeta,
        taskLower.isAcceptableOrUnknown(data['task_lower']!, _taskLowerMeta),
      );
    } else if (isInserting) {
      context.missing(_taskLowerMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      )!,
      statusChar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_char'],
      )!,
      taskText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_text'],
      )!,
      taskLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_lower'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  /// Unique task row ID.
  final int id;

  /// Note path referencing [Files.path].
  final String path;

  /// 0-based line number.
  final int line;

  /// Status character (' ' = open).
  final String statusChar;

  /// Task item text.
  final String taskText;

  /// Lower-cased task text.
  final String taskLower;

  /// Start offset of the task list item.
  final int startOffset;

  /// End offset of the task list item.
  final int endOffset;

  /// Due date string in 'YYYY-MM-DD' format if present.
  final String? due;
  const TaskRow({
    required this.id,
    required this.path,
    required this.line,
    required this.statusChar,
    required this.taskText,
    required this.taskLower,
    required this.startOffset,
    required this.endOffset,
    this.due,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['line'] = Variable<int>(line);
    map['status_char'] = Variable<String>(statusChar);
    map['task_text'] = Variable<String>(taskText);
    map['task_lower'] = Variable<String>(taskLower);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<String>(due);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      path: Value(path),
      line: Value(line),
      statusChar: Value(statusChar),
      taskText: Value(taskText),
      taskLower: Value(taskLower),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      line: serializer.fromJson<int>(json['line']),
      statusChar: serializer.fromJson<String>(json['statusChar']),
      taskText: serializer.fromJson<String>(json['taskText']),
      taskLower: serializer.fromJson<String>(json['taskLower']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      due: serializer.fromJson<String?>(json['due']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'line': serializer.toJson<int>(line),
      'statusChar': serializer.toJson<String>(statusChar),
      'taskText': serializer.toJson<String>(taskText),
      'taskLower': serializer.toJson<String>(taskLower),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'due': serializer.toJson<String?>(due),
    };
  }

  TaskRow copyWith({
    int? id,
    String? path,
    int? line,
    String? statusChar,
    String? taskText,
    String? taskLower,
    int? startOffset,
    int? endOffset,
    Value<String?> due = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    path: path ?? this.path,
    line: line ?? this.line,
    statusChar: statusChar ?? this.statusChar,
    taskText: taskText ?? this.taskText,
    taskLower: taskLower ?? this.taskLower,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    due: due.present ? due.value : this.due,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      line: data.line.present ? data.line.value : this.line,
      statusChar: data.statusChar.present
          ? data.statusChar.value
          : this.statusChar,
      taskText: data.taskText.present ? data.taskText.value : this.taskText,
      taskLower: data.taskLower.present ? data.taskLower.value : this.taskLower,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      due: data.due.present ? data.due.value : this.due,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('line: $line, ')
          ..write('statusChar: $statusChar, ')
          ..write('taskText: $taskText, ')
          ..write('taskLower: $taskLower, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('due: $due')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    line,
    statusChar,
    taskText,
    taskLower,
    startOffset,
    endOffset,
    due,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.line == this.line &&
          other.statusChar == this.statusChar &&
          other.taskText == this.taskText &&
          other.taskLower == this.taskLower &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.due == this.due);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> line;
  final Value<String> statusChar;
  final Value<String> taskText;
  final Value<String> taskLower;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<String?> due;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.line = const Value.absent(),
    this.statusChar = const Value.absent(),
    this.taskText = const Value.absent(),
    this.taskLower = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.due = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int line,
    required String statusChar,
    required String taskText,
    required String taskLower,
    required int startOffset,
    required int endOffset,
    this.due = const Value.absent(),
  }) : path = Value(path),
       line = Value(line),
       statusChar = Value(statusChar),
       taskText = Value(taskText),
       taskLower = Value(taskLower),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? line,
    Expression<String>? statusChar,
    Expression<String>? taskText,
    Expression<String>? taskLower,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? due,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (line != null) 'line': line,
      if (statusChar != null) 'status_char': statusChar,
      if (taskText != null) 'task_text': taskText,
      if (taskLower != null) 'task_lower': taskLower,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (due != null) 'due': due,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? line,
    Value<String>? statusChar,
    Value<String>? taskText,
    Value<String>? taskLower,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<String?>? due,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      line: line ?? this.line,
      statusChar: statusChar ?? this.statusChar,
      taskText: taskText ?? this.taskText,
      taskLower: taskLower ?? this.taskLower,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      due: due ?? this.due,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    if (statusChar.present) {
      map['status_char'] = Variable<String>(statusChar.value);
    }
    if (taskText.present) {
      map['task_text'] = Variable<String>(taskText.value);
    }
    if (taskLower.present) {
      map['task_lower'] = Variable<String>(taskLower.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (due.present) {
      map['due'] = Variable<String>(due.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('line: $line, ')
          ..write('statusChar: $statusChar, ')
          ..write('taskText: $taskText, ')
          ..write('taskLower: $taskLower, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('due: $due')
          ..write(')'))
        .toString();
  }
}

class $IndexMetaTable extends IndexMeta
    with TableInfo<$IndexMetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IndexMetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'index_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
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
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
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
  $IndexMetaTable createAlias(String alias) {
    return $IndexMetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  /// Metadata key.
  final String key;

  /// Metadata value.
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  IndexMetaCompanion toCompanion(bool nullToAbsent) {
    return IndexMetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
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

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(IndexMetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
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
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class IndexMetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const IndexMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IndexMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
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

  IndexMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return IndexMetaCompanion(
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
    return (StringBuffer('IndexMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TephraIndexDatabase extends GeneratedDatabase {
  _$TephraIndexDatabase(QueryExecutor e) : super(e);
  $TephraIndexDatabaseManager get managers => $TephraIndexDatabaseManager(this);
  late final $FilesTable files = $FilesTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $AliasesTable aliases = $AliasesTable(this);
  late final $HeadingsTable headings = $HeadingsTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $LinksTable links = $LinksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $PropertiesTable properties = $PropertiesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $IndexMetaTable indexMeta = $IndexMetaTable(this);
  late final Index filesCaseKey = Index(
    'files_case_key',
    'CREATE INDEX files_case_key ON files (case_key)',
  );
  late final Index filesNameKey = Index(
    'files_name_key',
    'CREATE INDEX files_name_key ON files (name_key)',
  );
  late final Index aliasesKey = Index(
    'aliases_key',
    'CREATE INDEX aliases_key ON aliases (alias_key)',
  );
  late final Index headingsPath = Index(
    'headings_path',
    'CREATE INDEX headings_path ON headings (path)',
  );
  late final Index blocksKey = Index(
    'blocks_key',
    'CREATE INDEX blocks_key ON blocks (block_key)',
  );
  late final Index linksSource = Index(
    'links_source',
    'CREATE INDEX links_source ON links (source)',
  );
  late final Index linksTargetPath = Index(
    'links_target_path',
    'CREATE INDEX links_target_path ON links (target_path)',
  );
  late final Index linksTargetKey = Index(
    'links_target_key',
    'CREATE INDEX links_target_key ON links (target_key)',
  );
  late final Index tagsLower = Index(
    'tags_lower',
    'CREATE INDEX tags_lower ON tags (tag_lower)',
  );
  late final Index tagsPath = Index(
    'tags_path',
    'CREATE INDEX tags_path ON tags (path)',
  );
  late final Index propertiesKey = Index(
    'properties_key',
    'CREATE INDEX properties_key ON properties (key_lower)',
  );
  late final Index propertiesPath = Index(
    'properties_path',
    'CREATE INDEX properties_path ON properties (path)',
  );
  late final Index tasksPath = Index(
    'tasks_path',
    'CREATE INDEX tasks_path ON tasks (path)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    files,
    notes,
    aliases,
    headings,
    blocks,
    links,
    tags,
    properties,
    tasks,
    indexMeta,
    filesCaseKey,
    filesNameKey,
    aliasesKey,
    headingsPath,
    blocksKey,
    linksSource,
    linksTargetPath,
    linksTargetKey,
    tagsLower,
    tagsPath,
    propertiesKey,
    propertiesPath,
    tasksPath,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('aliases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('headings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('properties', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FilesTableCreateCompanionBuilder = FilesCompanion Function({
  required String path,
  required String caseKey,
  required String nameKey,
  required String stemKey,
  required String folder,
  required String extension,
  required int size,
  required int mtime,
  Value<int?> created,
  required String hash,
  required bool isNote,
  Value<int> rowid,
});
typedef $$FilesTableUpdateCompanionBuilder = FilesCompanion Function({
  Value<String> path,
  Value<String> caseKey,
  Value<String> nameKey,
  Value<String> stemKey,
  Value<String> folder,
  Value<String> extension,
  Value<int> size,
  Value<int> mtime,
  Value<int?> created,
  Value<String> hash,
  Value<bool> isNote,
  Value<int> rowid,
});

final class $$FilesTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $FilesTable, FileRow> {
  $$FilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotesTable, List<NoteRow>> _notesRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'files__path__notes__path',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AliasesTable, List<AliasRow>> _aliasesRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.aliases,
    aliasName: 'files__path__aliases__path',
  );

  $$AliasesTableProcessedTableManager get aliasesRefs {
    final manager = $$AliasesTableTableManager(
      $_db,
      $_db.aliases,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_aliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HeadingsTable, List<HeadingRow>>
  _headingsRefsTable(_$TephraIndexDatabase db) => MultiTypedResultKey.fromTable(
    db.headings,
    aliasName: 'files__path__headings__path',
  );

  $$HeadingsTableProcessedTableManager get headingsRefs {
    final manager = $$HeadingsTableTableManager(
      $_db,
      $_db.headings,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_headingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BlocksTable, List<BlockRow>> _blocksRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.blocks,
    aliasName: 'files__path__blocks__path',
  );

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager(
      $_db,
      $_db.blocks,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LinksTable, List<LinkRow>> _linksRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.links,
    aliasName: 'files__path__links__source',
  );

  $$LinksTableProcessedTableManager get linksRefs {
    final manager = $$LinksTableTableManager(
      $_db,
      $_db.links,
    ).filter((f) => f.source.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_linksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TagsTable, List<TagRow>> _tagsRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tags,
    aliasName: 'files__path__tags__path',
  );

  $$TagsTableProcessedTableManager get tagsRefs {
    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_tagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PropertiesTable, List<PropertyRow>>
  _propertiesRefsTable(_$TephraIndexDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.properties,
        aliasName: 'files__path__properties__path',
      );

  $$PropertiesTableProcessedTableManager get propertiesRefs {
    final manager = $$PropertiesTableTableManager(
      $_db,
      $_db.properties,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_propertiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$TephraIndexDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'files__path__tasks__path',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.path.path.sqlEquals($_itemColumn<String>('path')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FilesTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $FilesTable> {
  $$FilesTableFilterComposer({
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

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stemKey => $composableBuilder(
    column: $table.stemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extension => $composableBuilder(
    column: $table.extension,
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

  ColumnFilters<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNote => $composableBuilder(
    column: $table.isNote,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> aliasesRefs(
    Expression<bool> Function($$AliasesTableFilterComposer f) f,
  ) {
    final $$AliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableFilterComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> headingsRefs(
    Expression<bool> Function($$HeadingsTableFilterComposer f) f,
  ) {
    final $$HeadingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.headings,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeadingsTableFilterComposer(
            $db: $db,
            $table: $db.headings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> blocksRefs(
    Expression<bool> Function($$BlocksTableFilterComposer f) f,
  ) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableFilterComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> linksRefs(
    Expression<bool> Function($$LinksTableFilterComposer f) f,
  ) {
    final $$LinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.links,
      getReferencedColumn: (t) => t.source,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LinksTableFilterComposer(
            $db: $db,
            $table: $db.links,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tagsRefs(
    Expression<bool> Function($$TagsTableFilterComposer f) f,
  ) {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> propertiesRefs(
    Expression<bool> Function($$PropertiesTableFilterComposer f) f,
  ) {
    final $$PropertiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.properties,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PropertiesTableFilterComposer(
            $db: $db,
            $table: $db.properties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FilesTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $FilesTable> {
  $$FilesTableOrderingComposer({
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

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stemKey => $composableBuilder(
    column: $table.stemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extension => $composableBuilder(
    column: $table.extension,
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

  ColumnOrderings<int> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNote => $composableBuilder(
    column: $table.isNote,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FilesTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $FilesTable> {
  $$FilesTableAnnotationComposer({
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

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get stemKey =>
      $composableBuilder(column: $table.stemKey, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get extension =>
      $composableBuilder(column: $table.extension, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<int> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<bool> get isNote =>
      $composableBuilder(column: $table.isNote, builder: (column) => column);

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> aliasesRefs<T extends Object>(
    Expression<T> Function($$AliasesTableAnnotationComposer a) f,
  ) {
    final $$AliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> headingsRefs<T extends Object>(
    Expression<T> Function($$HeadingsTableAnnotationComposer a) f,
  ) {
    final $$HeadingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.headings,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeadingsTableAnnotationComposer(
            $db: $db,
            $table: $db.headings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> blocksRefs<T extends Object>(
    Expression<T> Function($$BlocksTableAnnotationComposer a) f,
  ) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> linksRefs<T extends Object>(
    Expression<T> Function($$LinksTableAnnotationComposer a) f,
  ) {
    final $$LinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.links,
      getReferencedColumn: (t) => t.source,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LinksTableAnnotationComposer(
            $db: $db,
            $table: $db.links,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tagsRefs<T extends Object>(
    Expression<T> Function($$TagsTableAnnotationComposer a) f,
  ) {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> propertiesRefs<T extends Object>(
    Expression<T> Function($$PropertiesTableAnnotationComposer a) f,
  ) {
    final $$PropertiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.properties,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PropertiesTableAnnotationComposer(
            $db: $db,
            $table: $db.properties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FilesTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $FilesTable,
          FileRow,
          $$FilesTableFilterComposer,
          $$FilesTableOrderingComposer,
          $$FilesTableAnnotationComposer,
          $$FilesTableCreateCompanionBuilder,
          $$FilesTableUpdateCompanionBuilder,
          (FileRow, $$FilesTableReferences),
          FileRow,
          PrefetchHooks Function({
            bool notesRefs,
            bool aliasesRefs,
            bool headingsRefs,
            bool blocksRefs,
            bool linksRefs,
            bool tagsRefs,
            bool propertiesRefs,
            bool tasksRefs,
          })
        > {
  $$FilesTableTableManager(_$TephraIndexDatabase db, $FilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> caseKey = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<String> stemKey = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> extension = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<int?> created = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<bool> isNote = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion(
                path: path,
                caseKey: caseKey,
                nameKey: nameKey,
                stemKey: stemKey,
                folder: folder,
                extension: extension,
                size: size,
                mtime: mtime,
                created: created,
                hash: hash,
                isNote: isNote,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String caseKey,
                required String nameKey,
                required String stemKey,
                required String folder,
                required String extension,
                required int size,
                required int mtime,
                Value<int?> created = const Value.absent(),
                required String hash,
                required bool isNote,
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion.insert(
                path: path,
                caseKey: caseKey,
                nameKey: nameKey,
                stemKey: stemKey,
                folder: folder,
                extension: extension,
                size: size,
                mtime: mtime,
                created: created,
                hash: hash,
                isNote: isNote,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FilesTable, FileRow>(table),
                  $$FilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                notesRefs = false,
                aliasesRefs = false,
                headingsRefs = false,
                blocksRefs = false,
                linksRefs = false,
                tagsRefs = false,
                propertiesRefs = false,
                tasksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notesRefs) db.notes,
                    if (aliasesRefs) db.aliases,
                    if (headingsRefs) db.headings,
                    if (blocksRefs) db.blocks,
                    if (linksRefs) db.links,
                    if (tagsRefs) db.tags,
                    if (propertiesRefs) db.properties,
                    if (tasksRefs) db.tasks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notesRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          NoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (aliasesRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          AliasRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._aliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).aliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (headingsRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          HeadingRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._headingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(
                                db,
                                table,
                                p0,
                              ).headingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (blocksRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          BlockRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._blocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).blocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (linksRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          LinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._linksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).linksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.source == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (tagsRefs)
                        await $_getPrefetchedData<FileRow, $FilesTable, TagRow>(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._tagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).tagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (propertiesRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          PropertyRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._propertiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(
                                db,
                                table,
                                p0,
                              ).propertiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          FileRow,
                          $FilesTable,
                          TaskRow
                        >(
                          currentTable: table,
                          referencedTable: $$FilesTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FilesTableReferences(db, table, p0).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.path == item.path,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FilesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $FilesTable,
      FileRow,
      $$FilesTableFilterComposer,
      $$FilesTableOrderingComposer,
      $$FilesTableAnnotationComposer,
      $$FilesTableCreateCompanionBuilder,
      $$FilesTableUpdateCompanionBuilder,
      (FileRow, $$FilesTableReferences),
      FileRow,
      PrefetchHooks Function({
        bool notesRefs,
        bool aliasesRefs,
        bool headingsRefs,
        bool blocksRefs,
        bool linksRefs,
        bool tagsRefs,
        bool propertiesRefs,
        bool tasksRefs,
      })
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required String path,
  required String title,
  required String frontmatterJson,
  required bool frontmatterValid,
  required int wordCount,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> title,
  Value<String> frontmatterJson,
  Value<bool> frontmatterValid,
  Value<int> wordCount,
});

final class $$NotesTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $NotesTable, NoteRow> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('notes__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotesTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get frontmatterValid => $composableBuilder(
    column: $table.frontmatterValid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get frontmatterValid => $composableBuilder(
    column: $table.frontmatterValid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get frontmatterJson => $composableBuilder(
    column: $table.frontmatterJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get frontmatterValid => $composableBuilder(
    column: $table.frontmatterValid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, $$NotesTableReferences),
          NoteRow,
          PrefetchHooks Function({bool path})
        > {
  $$NotesTableTableManager(_$TephraIndexDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> frontmatterJson = const Value.absent(),
                Value<bool> frontmatterValid = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                path: path,
                title: title,
                frontmatterJson: frontmatterJson,
                frontmatterValid: frontmatterValid,
                wordCount: wordCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String title,
                required String frontmatterJson,
                required bool frontmatterValid,
                required int wordCount,
              }) => NotesCompanion.insert(
                id: id,
                path: path,
                title: title,
                frontmatterJson: frontmatterJson,
                frontmatterValid: frontmatterValid,
                wordCount: wordCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, NoteRow>(table),
                  $$NotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$NotesTableReferences._pathTable(db),
                        referencedColumn: $$NotesTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, $$NotesTableReferences),
      NoteRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$AliasesTableCreateCompanionBuilder = AliasesCompanion Function({
  required String path,
  required String alias,
  required String aliasKey,
  required int ordinal,
  Value<int> rowid,
});
typedef $$AliasesTableUpdateCompanionBuilder = AliasesCompanion Function({
  Value<String> path,
  Value<String> alias,
  Value<String> aliasKey,
  Value<int> ordinal,
  Value<int> rowid,
});

final class $$AliasesTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $AliasesTable, AliasRow> {
  $$AliasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('aliases__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AliasesTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $AliasesTable> {
  $$AliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasKey => $composableBuilder(
    column: $table.aliasKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $AliasesTable> {
  $$AliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasKey => $composableBuilder(
    column: $table.aliasKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $AliasesTable> {
  $$AliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get aliasKey =>
      $composableBuilder(column: $table.aliasKey, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $AliasesTable,
          AliasRow,
          $$AliasesTableFilterComposer,
          $$AliasesTableOrderingComposer,
          $$AliasesTableAnnotationComposer,
          $$AliasesTableCreateCompanionBuilder,
          $$AliasesTableUpdateCompanionBuilder,
          (AliasRow, $$AliasesTableReferences),
          AliasRow,
          PrefetchHooks Function({bool path})
        > {
  $$AliasesTableTableManager(_$TephraIndexDatabase db, $AliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<String> aliasKey = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AliasesCompanion(
                path: path,
                alias: alias,
                aliasKey: aliasKey,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String alias,
                required String aliasKey,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => AliasesCompanion.insert(
                path: path,
                alias: alias,
                aliasKey: aliasKey,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AliasesTable, AliasRow>(table),
                  $$AliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$AliasesTableReferences._pathTable(
                          db,
                        ),
                        referencedColumn: $$AliasesTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $AliasesTable,
      AliasRow,
      $$AliasesTableFilterComposer,
      $$AliasesTableOrderingComposer,
      $$AliasesTableAnnotationComposer,
      $$AliasesTableCreateCompanionBuilder,
      $$AliasesTableUpdateCompanionBuilder,
      (AliasRow, $$AliasesTableReferences),
      AliasRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$HeadingsTableCreateCompanionBuilder = HeadingsCompanion Function({
  required String path,
  required int ordinal,
  required int level,
  required String headingText,
  required String headingKey,
  required int startOffset,
  required int endOffset,
  required int line,
  Value<int> rowid,
});
typedef $$HeadingsTableUpdateCompanionBuilder = HeadingsCompanion Function({
  Value<String> path,
  Value<int> ordinal,
  Value<int> level,
  Value<String> headingText,
  Value<String> headingKey,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<int> line,
  Value<int> rowid,
});

final class $$HeadingsTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $HeadingsTable, HeadingRow> {
  $$HeadingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('headings__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HeadingsTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $HeadingsTable> {
  $$HeadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headingText => $composableBuilder(
    column: $table.headingText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headingKey => $composableBuilder(
    column: $table.headingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadingsTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $HeadingsTable> {
  $$HeadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headingText => $composableBuilder(
    column: $table.headingText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headingKey => $composableBuilder(
    column: $table.headingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadingsTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $HeadingsTable> {
  $$HeadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get headingText => $composableBuilder(
    column: $table.headingText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headingKey => $composableBuilder(
    column: $table.headingKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadingsTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $HeadingsTable,
          HeadingRow,
          $$HeadingsTableFilterComposer,
          $$HeadingsTableOrderingComposer,
          $$HeadingsTableAnnotationComposer,
          $$HeadingsTableCreateCompanionBuilder,
          $$HeadingsTableUpdateCompanionBuilder,
          (HeadingRow, $$HeadingsTableReferences),
          HeadingRow,
          PrefetchHooks Function({bool path})
        > {
  $$HeadingsTableTableManager(_$TephraIndexDatabase db, $HeadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String> headingText = const Value.absent(),
                Value<String> headingKey = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> line = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeadingsCompanion(
                path: path,
                ordinal: ordinal,
                level: level,
                headingText: headingText,
                headingKey: headingKey,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int ordinal,
                required int level,
                required String headingText,
                required String headingKey,
                required int startOffset,
                required int endOffset,
                required int line,
                Value<int> rowid = const Value.absent(),
              }) => HeadingsCompanion.insert(
                path: path,
                ordinal: ordinal,
                level: level,
                headingText: headingText,
                headingKey: headingKey,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HeadingsTable, HeadingRow>(table),
                  $$HeadingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$HeadingsTableReferences._pathTable(
                          db,
                        ),
                        referencedColumn: $$HeadingsTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HeadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $HeadingsTable,
      HeadingRow,
      $$HeadingsTableFilterComposer,
      $$HeadingsTableOrderingComposer,
      $$HeadingsTableAnnotationComposer,
      $$HeadingsTableCreateCompanionBuilder,
      $$HeadingsTableUpdateCompanionBuilder,
      (HeadingRow, $$HeadingsTableReferences),
      HeadingRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$BlocksTableCreateCompanionBuilder = BlocksCompanion Function({
  required String path,
  required String blockId,
  required String blockKey,
  required int startOffset,
  required int endOffset,
  required int line,
  required String preview,
  Value<int> rowid,
});
typedef $$BlocksTableUpdateCompanionBuilder = BlocksCompanion Function({
  Value<String> path,
  Value<String> blockId,
  Value<String> blockKey,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<int> line,
  Value<String> preview,
  Value<int> rowid,
});

final class $$BlocksTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $BlocksTable, BlockRow> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('blocks__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockKey => $composableBuilder(
    column: $table.blockKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockKey => $composableBuilder(
    column: $table.blockKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get blockKey =>
      $composableBuilder(column: $table.blockKey, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $BlocksTable,
          BlockRow,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (BlockRow, $$BlocksTableReferences),
          BlockRow,
          PrefetchHooks Function({bool path})
        > {
  $$BlocksTableTableManager(_$TephraIndexDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> blockKey = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> line = const Value.absent(),
                Value<String> preview = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion(
                path: path,
                blockId: blockId,
                blockKey: blockKey,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                preview: preview,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String blockId,
                required String blockKey,
                required int startOffset,
                required int endOffset,
                required int line,
                required String preview,
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion.insert(
                path: path,
                blockId: blockId,
                blockKey: blockKey,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                preview: preview,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlocksTable, BlockRow>(table),
                  $$BlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$BlocksTableReferences._pathTable(db),
                        referencedColumn: $$BlocksTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $BlocksTable,
      BlockRow,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (BlockRow, $$BlocksTableReferences),
      BlockRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$LinksTableCreateCompanionBuilder = LinksCompanion Function({
  Value<int> id,
  required String source,
  required String targetRaw,
  required String targetKey,
  Value<String?> targetPath,
  required String kind,
  required String syntax,
  Value<String?> heading,
  Value<String?> blockRef,
  Value<String?> alias,
  Value<String?> embedSize,
  required int startOffset,
  required int endOffset,
  required int line,
  required bool resolved,
  required bool viaAlias,
});
typedef $$LinksTableUpdateCompanionBuilder = LinksCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> targetRaw,
  Value<String> targetKey,
  Value<String?> targetPath,
  Value<String> kind,
  Value<String> syntax,
  Value<String?> heading,
  Value<String?> blockRef,
  Value<String?> alias,
  Value<String?> embedSize,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<int> line,
  Value<bool> resolved,
  Value<bool> viaAlias,
});

final class $$LinksTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $LinksTable, LinkRow> {
  $$LinksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _sourceTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('links__source__files__path');

  $$FilesTableProcessedTableManager get source {
    final $_column = $_itemColumn<String>('source')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LinksTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $LinksTable> {
  $$LinksTableFilterComposer({
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

  ColumnFilters<String> get targetRaw => $composableBuilder(
    column: $table.targetRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syntax => $composableBuilder(
    column: $table.syntax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockRef => $composableBuilder(
    column: $table.blockRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get embedSize => $composableBuilder(
    column: $table.embedSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get viaAlias => $composableBuilder(
    column: $table.viaAlias,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get source {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.source,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LinksTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $LinksTable> {
  $$LinksTableOrderingComposer({
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

  ColumnOrderings<String> get targetRaw => $composableBuilder(
    column: $table.targetRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syntax => $composableBuilder(
    column: $table.syntax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockRef => $composableBuilder(
    column: $table.blockRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embedSize => $composableBuilder(
    column: $table.embedSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get viaAlias => $composableBuilder(
    column: $table.viaAlias,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get source {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.source,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LinksTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $LinksTable> {
  $$LinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetRaw =>
      $composableBuilder(column: $table.targetRaw, builder: (column) => column);

  GeneratedColumn<String> get targetKey =>
      $composableBuilder(column: $table.targetKey, builder: (column) => column);

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get syntax =>
      $composableBuilder(column: $table.syntax, builder: (column) => column);

  GeneratedColumn<String> get heading =>
      $composableBuilder(column: $table.heading, builder: (column) => column);

  GeneratedColumn<String> get blockRef =>
      $composableBuilder(column: $table.blockRef, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get embedSize =>
      $composableBuilder(column: $table.embedSize, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  GeneratedColumn<bool> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);

  GeneratedColumn<bool> get viaAlias =>
      $composableBuilder(column: $table.viaAlias, builder: (column) => column);

  $$FilesTableAnnotationComposer get source {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.source,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LinksTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $LinksTable,
          LinkRow,
          $$LinksTableFilterComposer,
          $$LinksTableOrderingComposer,
          $$LinksTableAnnotationComposer,
          $$LinksTableCreateCompanionBuilder,
          $$LinksTableUpdateCompanionBuilder,
          (LinkRow, $$LinksTableReferences),
          LinkRow,
          PrefetchHooks Function({bool source})
        > {
  $$LinksTableTableManager(_$TephraIndexDatabase db, $LinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> targetRaw = const Value.absent(),
                Value<String> targetKey = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> syntax = const Value.absent(),
                Value<String?> heading = const Value.absent(),
                Value<String?> blockRef = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<String?> embedSize = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> line = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<bool> viaAlias = const Value.absent(),
              }) => LinksCompanion(
                id: id,
                source: source,
                targetRaw: targetRaw,
                targetKey: targetKey,
                targetPath: targetPath,
                kind: kind,
                syntax: syntax,
                heading: heading,
                blockRef: blockRef,
                alias: alias,
                embedSize: embedSize,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                resolved: resolved,
                viaAlias: viaAlias,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String targetRaw,
                required String targetKey,
                Value<String?> targetPath = const Value.absent(),
                required String kind,
                required String syntax,
                Value<String?> heading = const Value.absent(),
                Value<String?> blockRef = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<String?> embedSize = const Value.absent(),
                required int startOffset,
                required int endOffset,
                required int line,
                required bool resolved,
                required bool viaAlias,
              }) => LinksCompanion.insert(
                id: id,
                source: source,
                targetRaw: targetRaw,
                targetKey: targetKey,
                targetPath: targetPath,
                kind: kind,
                syntax: syntax,
                heading: heading,
                blockRef: blockRef,
                alias: alias,
                embedSize: embedSize,
                startOffset: startOffset,
                endOffset: endOffset,
                line: line,
                resolved: resolved,
                viaAlias: viaAlias,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LinksTable, LinkRow>(table),
                  $$LinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({source = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (source) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.source,
                        referencedTable: $$LinksTableReferences._sourceTable(
                          db,
                        ),
                        referencedColumn: $$LinksTableReferences
                            ._sourceTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LinksTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $LinksTable,
      LinkRow,
      $$LinksTableFilterComposer,
      $$LinksTableOrderingComposer,
      $$LinksTableAnnotationComposer,
      $$LinksTableCreateCompanionBuilder,
      $$LinksTableUpdateCompanionBuilder,
      (LinkRow, $$LinksTableReferences),
      LinkRow,
      PrefetchHooks Function({bool source})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String path,
  required String tag,
  required String tagLower,
  Value<int?> startOffset,
  Value<int?> line,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> tag,
  Value<String> tagLower,
  Value<int?> startOffset,
  Value<int?> line,
});

final class $$TagsTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('tags__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TagsTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagLower => $composableBuilder(
    column: $table.tagLower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagLower => $composableBuilder(
    column: $table.tagLower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get tagLower =>
      $composableBuilder(column: $table.tagLower, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool path})
        > {
  $$TagsTableTableManager(_$TephraIndexDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> tagLower = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> line = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                path: path,
                tag: tag,
                tagLower: tagLower,
                startOffset: startOffset,
                line: line,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String tag,
                required String tagLower,
                Value<int?> startOffset = const Value.absent(),
                Value<int?> line = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                path: path,
                tag: tag,
                tagLower: tagLower,
                startOffset: startOffset,
                line: line,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$TagsTableReferences._pathTable(db),
                        referencedColumn: $$TagsTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$PropertiesTableCreateCompanionBuilder = PropertiesCompanion Function({
  Value<int> id,
  required String path,
  required String key,
  required String keyLower,
  required String valueType,
  required int ordinal,
  Value<String?> valueText,
  Value<String?> valueLower,
  Value<double?> valueNum,
  Value<bool?> valueBool,
  Value<String?> valueDate,
});
typedef $$PropertiesTableUpdateCompanionBuilder = PropertiesCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> key,
  Value<String> keyLower,
  Value<String> valueType,
  Value<int> ordinal,
  Value<String?> valueText,
  Value<String?> valueLower,
  Value<double?> valueNum,
  Value<bool?> valueBool,
  Value<String?> valueDate,
});

final class $$PropertiesTableReferences
    extends
        BaseReferences<_$TephraIndexDatabase, $PropertiesTable, PropertyRow> {
  $$PropertiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('properties__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PropertiesTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $PropertiesTable> {
  $$PropertiesTableFilterComposer({
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

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyLower => $composableBuilder(
    column: $table.keyLower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueLower => $composableBuilder(
    column: $table.valueLower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valueNum => $composableBuilder(
    column: $table.valueNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get valueBool => $composableBuilder(
    column: $table.valueBool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PropertiesTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $PropertiesTable> {
  $$PropertiesTableOrderingComposer({
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

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyLower => $composableBuilder(
    column: $table.keyLower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueLower => $composableBuilder(
    column: $table.valueLower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valueNum => $composableBuilder(
    column: $table.valueNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get valueBool => $composableBuilder(
    column: $table.valueBool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PropertiesTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $PropertiesTable> {
  $$PropertiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get keyLower =>
      $composableBuilder(column: $table.keyLower, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get valueText =>
      $composableBuilder(column: $table.valueText, builder: (column) => column);

  GeneratedColumn<String> get valueLower => $composableBuilder(
    column: $table.valueLower,
    builder: (column) => column,
  );

  GeneratedColumn<double> get valueNum =>
      $composableBuilder(column: $table.valueNum, builder: (column) => column);

  GeneratedColumn<bool> get valueBool =>
      $composableBuilder(column: $table.valueBool, builder: (column) => column);

  GeneratedColumn<String> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PropertiesTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $PropertiesTable,
          PropertyRow,
          $$PropertiesTableFilterComposer,
          $$PropertiesTableOrderingComposer,
          $$PropertiesTableAnnotationComposer,
          $$PropertiesTableCreateCompanionBuilder,
          $$PropertiesTableUpdateCompanionBuilder,
          (PropertyRow, $$PropertiesTableReferences),
          PropertyRow,
          PrefetchHooks Function({bool path})
        > {
  $$PropertiesTableTableManager(
    _$TephraIndexDatabase db,
    $PropertiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropertiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropertiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropertiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> keyLower = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String?> valueText = const Value.absent(),
                Value<String?> valueLower = const Value.absent(),
                Value<double?> valueNum = const Value.absent(),
                Value<bool?> valueBool = const Value.absent(),
                Value<String?> valueDate = const Value.absent(),
              }) => PropertiesCompanion(
                id: id,
                path: path,
                key: key,
                keyLower: keyLower,
                valueType: valueType,
                ordinal: ordinal,
                valueText: valueText,
                valueLower: valueLower,
                valueNum: valueNum,
                valueBool: valueBool,
                valueDate: valueDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String key,
                required String keyLower,
                required String valueType,
                required int ordinal,
                Value<String?> valueText = const Value.absent(),
                Value<String?> valueLower = const Value.absent(),
                Value<double?> valueNum = const Value.absent(),
                Value<bool?> valueBool = const Value.absent(),
                Value<String?> valueDate = const Value.absent(),
              }) => PropertiesCompanion.insert(
                id: id,
                path: path,
                key: key,
                keyLower: keyLower,
                valueType: valueType,
                ordinal: ordinal,
                valueText: valueText,
                valueLower: valueLower,
                valueNum: valueNum,
                valueBool: valueBool,
                valueDate: valueDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PropertiesTable, PropertyRow>(table),
                  $$PropertiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$PropertiesTableReferences._pathTable(
                          db,
                        ),
                        referencedColumn: $$PropertiesTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PropertiesTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $PropertiesTable,
      PropertyRow,
      $$PropertiesTableFilterComposer,
      $$PropertiesTableOrderingComposer,
      $$PropertiesTableAnnotationComposer,
      $$PropertiesTableCreateCompanionBuilder,
      $$PropertiesTableUpdateCompanionBuilder,
      (PropertyRow, $$PropertiesTableReferences),
      PropertyRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  required String path,
  required int line,
  required String statusChar,
  required String taskText,
  required String taskLower,
  required int startOffset,
  required int endOffset,
  Value<String?> due,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<int> line,
  Value<String> statusChar,
  Value<String> taskText,
  Value<String> taskLower,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<String?> due,
});

final class $$TasksTableReferences
    extends BaseReferences<_$TephraIndexDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTable _pathTable(_$TephraIndexDatabase db) =>
      db.files.createAlias('tasks__path__files__path');

  $$FilesTableProcessedTableManager get path {
    final $_column = $_itemColumn<String>('path')!;

    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TasksTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
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

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusChar => $composableBuilder(
    column: $table.statusChar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskText => $composableBuilder(
    column: $table.taskText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskLower => $composableBuilder(
    column: $table.taskLower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  $$FilesTableFilterComposer get path {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
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

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusChar => $composableBuilder(
    column: $table.statusChar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskText => $composableBuilder(
    column: $table.taskText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskLower => $composableBuilder(
    column: $table.taskLower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  $$FilesTableOrderingComposer get path {
    final $$FilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableOrderingComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  GeneratedColumn<String> get statusChar => $composableBuilder(
    column: $table.statusChar,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskText =>
      $composableBuilder(column: $table.taskText, builder: (column) => column);

  GeneratedColumn<String> get taskLower =>
      $composableBuilder(column: $table.taskLower, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  $$FilesTableAnnotationComposer get path {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.path,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.path,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({bool path})
        > {
  $$TasksTableTableManager(_$TephraIndexDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> line = const Value.absent(),
                Value<String> statusChar = const Value.absent(),
                Value<String> taskText = const Value.absent(),
                Value<String> taskLower = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<String?> due = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                path: path,
                line: line,
                statusChar: statusChar,
                taskText: taskText,
                taskLower: taskLower,
                startOffset: startOffset,
                endOffset: endOffset,
                due: due,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int line,
                required String statusChar,
                required String taskText,
                required String taskLower,
                required int startOffset,
                required int endOffset,
                Value<String?> due = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                path: path,
                line: line,
                statusChar: statusChar,
                taskText: taskText,
                taskLower: taskLower,
                startOffset: startOffset,
                endOffset: endOffset,
                due: due,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({path = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (path) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.path,
                        referencedTable: $$TasksTableReferences._pathTable(db),
                        referencedColumn: $$TasksTableReferences
                            ._pathTable(db)
                            .path,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({bool path})
    >;
typedef $$IndexMetaTableCreateCompanionBuilder = IndexMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$IndexMetaTableUpdateCompanionBuilder = IndexMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$IndexMetaTableFilterComposer
    extends Composer<_$TephraIndexDatabase, $IndexMetaTable> {
  $$IndexMetaTableFilterComposer({
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

class $$IndexMetaTableOrderingComposer
    extends Composer<_$TephraIndexDatabase, $IndexMetaTable> {
  $$IndexMetaTableOrderingComposer({
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

class $$IndexMetaTableAnnotationComposer
    extends Composer<_$TephraIndexDatabase, $IndexMetaTable> {
  $$IndexMetaTableAnnotationComposer({
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

class $$IndexMetaTableTableManager
    extends
        RootTableManager<
          _$TephraIndexDatabase,
          $IndexMetaTable,
          MetaRow,
          $$IndexMetaTableFilterComposer,
          $$IndexMetaTableOrderingComposer,
          $$IndexMetaTableAnnotationComposer,
          $$IndexMetaTableCreateCompanionBuilder,
          $$IndexMetaTableUpdateCompanionBuilder,
          (
            MetaRow,
            BaseReferences<_$TephraIndexDatabase, $IndexMetaTable, MetaRow>,
          ),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$IndexMetaTableTableManager(_$TephraIndexDatabase db, $IndexMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IndexMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IndexMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IndexMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => IndexMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => IndexMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IndexMetaTable, MetaRow>(table),
                  BaseReferences<
                    _$TephraIndexDatabase,
                    $IndexMetaTable,
                    MetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IndexMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$TephraIndexDatabase,
      $IndexMetaTable,
      MetaRow,
      $$IndexMetaTableFilterComposer,
      $$IndexMetaTableOrderingComposer,
      $$IndexMetaTableAnnotationComposer,
      $$IndexMetaTableCreateCompanionBuilder,
      $$IndexMetaTableUpdateCompanionBuilder,
      (
        MetaRow,
        BaseReferences<_$TephraIndexDatabase, $IndexMetaTable, MetaRow>,
      ),
      MetaRow,
      PrefetchHooks Function()
    >;

class $TephraIndexDatabaseManager {
  final _$TephraIndexDatabase _db;
  $TephraIndexDatabaseManager(this._db);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db, _db.files);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$AliasesTableTableManager get aliases =>
      $$AliasesTableTableManager(_db, _db.aliases);
  $$HeadingsTableTableManager get headings =>
      $$HeadingsTableTableManager(_db, _db.headings);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$LinksTableTableManager get links =>
      $$LinksTableTableManager(_db, _db.links);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$PropertiesTableTableManager get properties =>
      $$PropertiesTableTableManager(_db, _db.properties);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$IndexMetaTableTableManager get indexMeta =>
      $$IndexMetaTableTableManager(_db, _db.indexMeta);
}
