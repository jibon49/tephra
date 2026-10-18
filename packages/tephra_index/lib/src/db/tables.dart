// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';

/// Every vault file the indexer knows (notes and attachments).
@DataClassName('FileRow')
@TableIndex(name: 'files_case_key', columns: {#caseKey})
@TableIndex(name: 'files_name_key', columns: {#nameKey})
class Files extends Table {
  /// Vault-relative path value (VaultPath.value).
  TextColumn get path => text()();

  /// Normalized case key for case-insensitive lookup (VaultPath.caseKey).
  TextColumn get caseKey => text()();

  /// File name in lower-case with extension ('note.md', 'image.png').
  TextColumn get nameKey => text()();

  /// File stem in lower-case ('note').
  TextColumn get stemKey => text()();

  /// Parent folder path, empty string for root.
  TextColumn get folder => text()();

  /// Lower-case file extension ('md', 'png', '').
  TextColumn get extension => text()();

  /// File size in bytes.
  IntColumn get size => integer()();

  /// Last modification timestamp in milliseconds since epoch, UTC.
  IntColumn get mtime => integer()();

  /// Creation timestamp in milliseconds since epoch, UTC (null if unavailable).
  IntColumn get created => integer().nullable()();

  /// SHA-256 contentHash of the raw bytes.
  TextColumn get hash => text()();

  /// True if the file is a markdown note (extension == 'md').
  BoolColumn get isNote => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// One row per Markdown note. [id] is the rowid of both FTS tables.
@DataClassName('NoteRow')
class Notes extends Table {
  /// Auto-incrementing identifier matching the FTS rowids.
  IntColumn get id => integer().autoIncrement()();

  /// Vault path referencing [Files.path].
  TextColumn get path =>
      text().unique().references(Files, #path, onDelete: KeyAction.cascade)();

  /// File stem title.
  TextColumn get title => text()();

  /// JSON-encoded frontmatter map ('{}' if none or invalid).
  TextColumn get frontmatterJson => text()();

  /// True if the frontmatter was valid YAML.
  BoolColumn get frontmatterValid => boolean()();

  /// Word count of the note text.
  IntColumn get wordCount => integer()();
}

/// Frontmatter aliases defined for notes.
@DataClassName('AliasRow')
@TableIndex(name: 'aliases_key', columns: {#aliasKey})
class Aliases extends Table {
  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// Original-casing alias text.
  TextColumn get alias => text()();

  /// Lower-cased alias key.
  TextColumn get aliasKey => text()();

  /// Position ordinal in the aliases list.
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path, ordinal};
}

/// Headings present in Markdown notes.
@DataClassName('HeadingRow')
@TableIndex(name: 'headings_path', columns: {#path})
class Headings extends Table {
  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// 0-based order of the heading in the note.
  IntColumn get ordinal => integer()();

  /// Heading level (1..6).
  IntColumn get level => integer()();

  /// Text without '#' markers or trailing block identifiers.
  TextColumn get headingText => text()();

  /// Normalized heading key.
  TextColumn get headingKey => text()();

  /// Start offset in the normalized note content.
  IntColumn get startOffset => integer()();

  /// End offset in the normalized note content.
  IntColumn get endOffset => integer()();

  /// 0-based line number of the heading.
  IntColumn get line => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path, ordinal};
}

/// Block identifiers defined in Markdown notes.
@DataClassName('BlockRow')
@TableIndex(name: 'blocks_key', columns: {#blockKey})
class Blocks extends Table {
  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// Block ID string without leading '^'.
  TextColumn get blockId => text()();

  /// Lower-cased block ID key.
  TextColumn get blockKey => text()();

  /// Start offset of the owning block.
  IntColumn get startOffset => integer()();

  /// End offset of the owning block.
  IntColumn get endOffset => integer()();

  /// 0-based line number.
  IntColumn get line => integer()();

  /// Short preview of the block text (single line, up to 120 chars).
  TextColumn get preview => text()();

  @override
  Set<Column<Object>> get primaryKey => {path, blockId};
}

/// Links and embeds found in notes.
@DataClassName('LinkRow')
@TableIndex(name: 'links_source', columns: {#source})
@TableIndex(name: 'links_target_path', columns: {#targetPath})
@TableIndex(name: 'links_target_key', columns: {#targetKey})
class Links extends Table {
  /// Unique link row ID.
  IntColumn get id => integer().autoIncrement()();

  /// Source note path referencing [Files.path].
  TextColumn get source =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// Target string as written without subpath or alias.
  TextColumn get targetRaw => text()();

  /// Link target lookup key.
  TextColumn get targetKey => text()();

  /// Resolved target vault path value (null if unresolved).
  TextColumn get targetPath => text().nullable()();

  /// Kind: 'link' or 'embed'.
  TextColumn get kind => text()();

  /// Syntax: 'wiki' or 'markdown'.
  TextColumn get syntax => text()();

  /// Target heading path chain ('H1#H2') if present.
  TextColumn get heading => text().nullable()();

  /// Target block reference ID without '^' if present.
  TextColumn get blockRef => text().nullable()();

  /// Display text alias.
  TextColumn get alias => text().nullable()();

  /// Embed dimensions string ('300' or '300x200').
  TextColumn get embedSize => text().nullable()();

  /// Start offset including '!' for embeds.
  IntColumn get startOffset => integer()();

  /// End offset.
  IntColumn get endOffset => integer()();

  /// Line number.
  IntColumn get line => integer()();

  /// True if resolved to a vault file.
  BoolColumn get resolved => boolean()();

  /// True if resolved via a note's frontmatter alias.
  BoolColumn get viaAlias => boolean()();
}

/// Tags found in note text or frontmatter.
@DataClassName('TagRow')
@TableIndex(name: 'tags_lower', columns: {#tagLower})
@TableIndex(name: 'tags_path', columns: {#path})
class Tags extends Table {
  /// Unique tag row ID.
  IntColumn get id => integer().autoIncrement()();

  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// Tag string without '#', original case.
  TextColumn get tag => text()();

  /// Lower-case tag string.
  TextColumn get tagLower => text()();

  /// Start offset in content (null for frontmatter tags).
  IntColumn get startOffset => integer().nullable()();

  /// Line number in content (null for frontmatter tags).
  IntColumn get line => integer().nullable()();
}

/// Frontmatter properties extracted from notes.
@DataClassName('PropertyRow')
@TableIndex(name: 'properties_key', columns: {#keyLower})
@TableIndex(name: 'properties_path', columns: {#path})
class Properties extends Table {
  /// Unique property row ID.
  IntColumn get id => integer().autoIncrement()();

  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// Property key in original case.
  TextColumn get key => text()();

  /// Lower-case property key.
  TextColumn get keyLower => text()();

  /// Inferred type: text|multitext|number|checkbox|date|datetime|aliases|tags.
  TextColumn get valueType => text()();

  /// List element index (0 for scalar properties).
  IntColumn get ordinal => integer()();

  /// String value representation (null for null values or empty lists).
  TextColumn get valueText => text().nullable()();

  /// Lower-case string value.
  TextColumn get valueLower => text().nullable()();

  /// Numeric representation if numeric.
  RealColumn get valueNum => real().nullable()();

  /// Boolean representation if boolean.
  BoolColumn get valueBool => boolean().nullable()();

  /// Formatted date/datetime string if date/datetime.
  TextColumn get valueDate => text().nullable()();
}

/// Task checklist items found in notes.
@DataClassName('TaskRow')
@TableIndex(name: 'tasks_path', columns: {#path})
class Tasks extends Table {
  /// Unique task row ID.
  IntColumn get id => integer().autoIncrement()();

  /// Note path referencing [Files.path].
  TextColumn get path =>
      text().references(Files, #path, onDelete: KeyAction.cascade)();

  /// 0-based line number.
  IntColumn get line => integer()();

  /// Status character (' ' = open).
  TextColumn get statusChar => text()();

  /// Task item text.
  TextColumn get taskText => text()();

  /// Lower-cased task text.
  TextColumn get taskLower => text()();

  /// Start offset of the task list item.
  IntColumn get startOffset => integer()();

  /// End offset of the task list item.
  IntColumn get endOffset => integer()();

  /// Due date string in 'YYYY-MM-DD' format if present.
  TextColumn get due => text().nullable()();
}

/// Key/value facts about the index itself (parserVersion, lastReconcile, vaultRoot).
@DataClassName('MetaRow')
class IndexMeta extends Table {
  /// Metadata key.
  TextColumn get key => text()();

  /// Metadata value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
