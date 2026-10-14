// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../db/fts.dart';
import '../db/index_database.dart';
import '../extract/link_target_key.dart';
import '../extract/note_extractor.dart';
import '../links/link_resolver.dart';
import '../links/name_table.dart';
import '../model/index_event.dart';
import '../model/index_options.dart';
import '../model/index_progress.dart';
import 'ignore_rules.dart';

final class _WriteResult {
  const _WriteResult(this.oldAliasKeys, this.newAliasKeys);
  final List<String> oldAliasKeys;
  final List<String> newAliasKeys;
}

/// Core indexing and link resolution engine, running in-process or inside a worker isolate.
final class IndexerCore {
  IndexerCore({
    required this.db,
    required this.fs,
    required this.options,
    required this.clock,
    required this.onProgress,
    required this.onEvent,
  });

  final TephraIndexDatabase db;
  final VaultFileSystem fs;
  final IndexOptions options;
  final Clock clock;
  final void Function(IndexProgress) onProgress;
  final void Function(IndexEvent) onEvent;

  final Logger _log = Logger('index');
  NameTable _nameTable = NameTable();

  /// In-memory name and alias lookup table.
  NameTable get nameTable => _nameTable;

  /// Loads the in-memory [NameTable] from existing database rows.
  Future<void> loadNameTable() async {
    final fileRows = await (db.select(
      db.files,
    )..orderBy([(f) => OrderingTerm.asc(f.path)])).get();
    final aliasRows =
        await (db.select(db.aliases)..orderBy([
              (a) => OrderingTerm.asc(a.path),
              (a) => OrderingTerm.asc(a.ordinal),
            ]))
            .get();

    final aliasesMap = <VaultPath, List<String>>{};
    for (final a in aliasRows) {
      final vp = VaultPath(a.path);
      aliasesMap.putIfAbsent(vp, () => <String>[]).add(a.alias);
    }

    _nameTable = NameTable.from(
      fileRows.map((f) => VaultPath(f.path)),
      aliasesMap,
    );
  }

  /// Reconciles the database with the filesystem (startup and full index).
  Future<void> reconcile() async {
    onProgress(
      const IndexProgress(phase: IndexPhase.scanning, done: 0, total: 0),
    );

    final rawEntries = await fs.list(recursive: true);
    final entries = rawEntries
        .where((e) => !e.isFolder && isIndexable(e.path, options))
        .toList();

    final dbRows = await db.select(db.files).get();
    final dbMap = {for (final r in dbRows) r.path: r};
    final wasEmpty = dbRows.isEmpty;

    final entryPathSet = entries.map((e) => e.path.value).toSet();
    final deleted = dbRows
        .where((r) => !entryPathSet.contains(r.path))
        .map((r) => VaultPath(r.path))
        .toList();

    final dirty = <String>{};

    // 1. Delete disappeared files
    final batchSize = options.batchSize > 0 ? options.batchSize : 200;
    for (var i = 0; i < deleted.length; i += batchSize) {
      final chunk = deleted.sublist(
        i,
        i + batchSize > deleted.length ? deleted.length : i + batchSize,
      );
      await db.transaction(() async {
        for (final p in chunk) {
          dirty.addAll(await _deleteFile(p));
        }
      });
    }

    // 2. Classify toIndex vs touchOnly vs unchanged
    final toIndex = <VaultEntry>[];
    final touchOnly = <VaultEntry>[];
    final bytesMap = <VaultPath, List<int>>{};
    final hashMap = <VaultPath, String>{};

    for (final e in entries) {
      final row = dbMap[e.path.value];
      if (row == null) {
        toIndex.add(e);
        _nameTable.addFile(e.path); // Add BEFORE parsing anything!
        dirty.addAll(fileTargetKeys(e.path));
      } else if (row.size == e.size &&
          row.mtime == e.modified.toUtc().millisecondsSinceEpoch) {
        continue; // Fast path!
      } else {
        try {
          final bytes = await fs.readBytes(e.path);
          final h = contentHash(bytes);
          if (h == row.hash) {
            touchOnly.add(e);
          } else {
            toIndex.add(e);
            bytesMap[e.path] = bytes;
            hashMap[e.path] = h;
          }
        } catch (err, st) {
          _log.warning('Failed to read ${e.path}', err, st);
          await db.transaction(() async {
            await _deleteFile(e.path);
          });
        }
      }
    }

    // 3. Apply touchOnly in one transaction
    if (touchOnly.isNotEmpty) {
      await db.transaction(() async {
        await db.batch((batch) {
          for (final e in touchOnly) {
            batch.update(
              db.files,
              FilesCompanion(
                size: Value(e.size),
                mtime: Value(e.modified.toUtc().millisecondsSinceEpoch),
              ),
              where: (f) => f.path.equals(e.path.value),
            );
          }
        });
      });
    }

    // 4. Index modified or new files
    var doneSoFar = 0;
    for (var i = 0; i < toIndex.length; i += batchSize) {
      final batch = toIndex.sublist(
        i,
        i + batchSize > toIndex.length ? toIndex.length : i + batchSize,
      );

      // Read missing bytes outside of transaction
      for (final e in batch) {
        if (!bytesMap.containsKey(e.path)) {
          try {
            final bytes = await fs.readBytes(e.path);
            bytesMap[e.path] = bytes;
            hashMap[e.path] = contentHash(bytes);
          } catch (err, st) {
            _log.warning('Failed to read ${e.path}', err, st);
          }
        }
      }

      final indexedPaths = <VaultPath>{};
      await db.transaction(() async {
        for (final e in batch) {
          final bytes = bytesMap[e.path];
          final hash = hashMap[e.path];
          if (bytes == null || hash == null) {
            await _deleteFile(e.path);
            continue;
          }
          try {
            final r = await _writeFile(e.path, e, bytes, hash);
            dirty.addAll(_symmetricDifference(r.oldAliasKeys, r.newAliasKeys));
            indexedPaths.add(e.path);
          } catch (err, st) {
            _log.warning('Failed to parse or write ${e.path}', err, st);
            await _deleteFile(e.path);
          }
        }
      });

      doneSoFar += batch.length;
      onProgress(
        IndexProgress(
          phase: IndexPhase.indexing,
          done: doneSoFar,
          total: toIndex.length,
        ),
      );
      onEvent(IndexEvent(changedPaths: indexedPaths, fullRebuild: wasEmpty));
    }

    // 5. Re-resolve links
    onProgress(
      IndexProgress(
        phase: IndexPhase.resolving,
        done: toIndex.length,
        total: toIndex.length,
      ),
    );

    final Set<String> changed;
    if (wasEmpty) {
      changed = await _reresolveAllUnresolved();
    } else {
      changed = await _reresolve(dirty);
    }

    await db
        .into(db.indexMeta)
        .insertOnConflictUpdate(
          MetaRow(
            key: 'lastReconcile',
            value: clock.now().toUtc().toIso8601String(),
          ),
        );

    final allChanged = {
      for (final e in toIndex) e.path,
      for (final c in changed) VaultPath(c),
    };
    onEvent(IndexEvent(changedPaths: allChanged, fullRebuild: wasEmpty));
    onProgress(
      IndexProgress(
        phase: IndexPhase.done,
        done: toIndex.length,
        total: toIndex.length,
      ),
    );
  }

  /// Incrementally applies a single filesystem change.
  Future<void> apply(VaultChange change) async {
    switch (change) {
      case FileCreated(:final path) || FileModified(:final path):
        final entry = await fs.stat(path);
        if (entry == null) {
          await _handleDeleted(path);
          return;
        }
        if (entry.isFolder) {
          final children = await fs.list(folder: path, recursive: true);
          for (final child in children) {
            if (!child.isFolder && isIndexable(child.path, options)) {
              await apply(FileCreated(child.path));
            }
          }
          return;
        }
        if (!isIndexable(path, options)) return;

        final List<int> bytes;
        try {
          bytes = await fs.readBytes(path);
        } catch (err, st) {
          _log.warning('Failed to read $path', err, st);
          return;
        }
        final hash = contentHash(bytes);
        final row = await (db.select(
          db.files,
        )..where((f) => f.path.equals(path.value))).getSingleOrNull();

        if (row != null && row.hash == hash) {
          await (db.update(
            db.files,
          )..where((f) => f.path.equals(path.value))).write(
            FilesCompanion(
              size: Value(entry.size),
              mtime: Value(entry.modified.toUtc().millisecondsSinceEpoch),
            ),
          );
          return;
        }

        final isNew = row == null;
        if (isNew) {
          _nameTable.addFile(path);
        }

        late _WriteResult r;
        await db.transaction(() async {
          r = await _writeFile(path, entry, bytes, hash);
        });

        final dirty = (isNew ? fileTargetKeys(path) : <String>{}).union(
          _symmetricDifference(r.oldAliasKeys, r.newAliasKeys),
        );
        final changed = await _reresolve(dirty);

        onEvent(
          IndexEvent(
            changedPaths: {path, for (final c in changed) VaultPath(c)},
            fullRebuild: false,
          ),
        );

      case FileDeleted(:final path):
        await _handleDeleted(path);

      case FileMoved(:final from, :final path):
        final allFiles = await db.select(db.files).get();
        final victims = allFiles
            .map((f) => VaultPath(f.path))
            .where((p) => p == from || p.isWithin(from))
            .toList();

        final dirty = <String>{};
        await db.transaction(() async {
          for (final o in victims) {
            dirty.addAll(await _deleteFile(o));
          }
        });

        final reindexed = <VaultPath>{};
        for (final o in victims) {
          final suffix = o == from ? '' : o.value.substring(from.value.length);
          final n = VaultPath(path.value + suffix);
          final stat = await fs.stat(n);
          if (stat != null && !stat.isFolder && isIndexable(n, options)) {
            _nameTable.addFile(n);
            try {
              final bytes = await fs.readBytes(n);
              final hash = contentHash(bytes);
              late _WriteResult r;
              await db.transaction(() async {
                r = await _writeFile(n, stat, bytes, hash);
              });
              dirty.addAll(fileTargetKeys(n));
              dirty.addAll(
                _symmetricDifference(r.oldAliasKeys, r.newAliasKeys),
              );
              reindexed.add(n);
            } catch (err, st) {
              _log.warning('Failed to read moved file $n', err, st);
            }
          }
        }

        final changed = await _reresolve(dirty);
        onEvent(
          IndexEvent(
            changedPaths: {
              ...victims,
              ...reindexed,
              for (final c in changed) VaultPath(c),
            },
            fullRebuild: false,
          ),
        );
    }
  }

  Future<void> _handleDeleted(VaultPath path) async {
    final allFiles = await db.select(db.files).get();
    final victims = allFiles
        .map((f) => VaultPath(f.path))
        .where((p) => p == path || p.isWithin(path))
        .toList();

    if (victims.isEmpty) return;

    final dirty = <String>{};
    await db.transaction(() async {
      for (final v in victims) {
        dirty.addAll(await _deleteFile(v));
      }
    });

    final changed = await _reresolve(dirty);
    onEvent(
      IndexEvent(
        changedPaths: {...victims, for (final c in changed) VaultPath(c)},
        fullRebuild: false,
      ),
    );
  }

  /// Wipes all tables and performs a full reconcile.
  Future<void> rebuild() async {
    await db.transaction(() async {
      await db.delete(db.tasks).go();
      await db.delete(db.properties).go();
      await db.delete(db.tags).go();
      await db.delete(db.links).go();
      await db.delete(db.blocks).go();
      await db.delete(db.headings).go();
      await db.delete(db.aliases).go();
      await db.delete(db.notes).go();
      await db.delete(db.files).go();
      await db.customStatement('DROP TABLE IF EXISTS fts_words');
      await db.customStatement('DROP TABLE IF EXISTS fts_trigram');
      await db.customStatement(ftsWordsDdl);
      await db.customStatement(ftsTrigramDdl);
    });
    _nameTable = NameTable();
    await reconcile();
  }

  Future<_WriteResult> _writeFile(
    VaultPath path,
    VaultEntry entry,
    List<int> bytes,
    String hash,
  ) async {
    final oldAliases = _nameTable.aliasesOf(path);
    final oldAliasKeys = oldAliases.map((a) => a.toLowerCase()).toList();

    final noteRow = await (db.select(
      db.notes,
    )..where((n) => n.path.equals(path.value))).getSingleOrNull();

    if (noteRow != null) {
      await ftsDelete(db, noteRow.id);
      await (db.delete(
        db.aliases,
      )..where((t) => t.path.equals(path.value))).go();
      await (db.delete(
        db.headings,
      )..where((t) => t.path.equals(path.value))).go();
      await (db.delete(
        db.blocks,
      )..where((t) => t.path.equals(path.value))).go();
      await (db.delete(db.tags)..where((t) => t.path.equals(path.value))).go();
      await (db.delete(
        db.properties,
      )..where((t) => t.path.equals(path.value))).go();
      await (db.delete(db.tasks)..where((t) => t.path.equals(path.value))).go();
      await (db.delete(
        db.links,
      )..where((t) => t.source.equals(path.value))).go();
      await (db.delete(db.notes)..where((t) => t.path.equals(path.value))).go();
    }

    final isNote = path.isMarkdown;
    final fileCompanion = FilesCompanion.insert(
      path: path.value,
      caseKey: path.caseKey,
      nameKey: path.name.toLowerCase(),
      stemKey: path.stem.toLowerCase(),
      folder: path.parent?.value ?? '',
      extension: path.extension,
      size: entry.size,
      mtime: entry.modified.toUtc().millisecondsSinceEpoch,
      created: Value(entry.created?.toUtc().millisecondsSinceEpoch),
      hash: hash,
      isNote: isNote,
    );
    await db.into(db.files).insertOnConflictUpdate(fileCompanion);

    if (isNote) {
      final doc = TextDocument.decode(bytes);
      final parsed = MarkdownParser.parse(doc.text);
      final x = NoteExtractor.extract(path, parsed);

      final noteCompanion = NotesCompanion.insert(
        path: path.value,
        title: x.title,
        frontmatterJson: x.frontmatterJson,
        frontmatterValid: x.frontmatterValid,
        wordCount: x.wordCount,
      );
      final noteId = await db.into(db.notes).insert(noteCompanion);

      await ftsInsert(db, noteId, x.ftsName, x.ftsBody);

      final resolver = LinkResolver(_nameTable);
      await db.batch((batch) {
        // Aliases
        for (var i = 0; i < x.aliases.length; i++) {
          final a = x.aliases[i];
          batch.insert(
            db.aliases,
            AliasesCompanion.insert(
              path: path.value,
              alias: a,
              aliasKey: a.toLowerCase(),
              ordinal: i,
            ),
          );
        }

        // Headings
        for (final h in x.headings) {
          batch.insert(
            db.headings,
            HeadingsCompanion.insert(
              path: path.value,
              ordinal: h.ordinal,
              level: h.level,
              headingText: h.text,
              headingKey: h.key,
              startOffset: h.start,
              endOffset: h.end,
              line: h.line,
            ),
          );
        }

        // Blocks
        for (final b in x.blocks) {
          batch.insert(
            db.blocks,
            BlocksCompanion.insert(
              path: path.value,
              blockId: b.id,
              blockKey: b.id.toLowerCase(),
              startOffset: b.start,
              endOffset: b.end,
              line: b.line,
              preview: b.preview,
            ),
          );
        }

        // Links
        for (final l in x.links) {
          final r = resolver.resolve(l.targetRaw, from: path);
          batch.insert(
            db.links,
            LinksCompanion.insert(
              source: path.value,
              targetRaw: l.targetRaw,
              targetKey: l.targetKey,
              targetPath: Value(r?.path.value),
              kind: l.kind.name,
              syntax: l.syntax.name,
              heading: Value(l.heading),
              blockRef: Value(l.blockRef),
              alias: Value(l.alias),
              embedSize: Value(l.embedSize),
              startOffset: l.start,
              endOffset: l.end,
              line: l.line,
              resolved: r != null,
              viaAlias: r?.viaAlias ?? false,
            ),
          );
        }

        // Tags
        for (final t in x.tags) {
          batch.insert(
            db.tags,
            TagsCompanion.insert(
              path: path.value,
              tag: t.tag,
              tagLower: t.tag.toLowerCase(),
              startOffset: Value(t.start),
              line: Value(t.line),
            ),
          );
        }

        // Properties
        for (final p in x.properties) {
          batch.insert(
            db.properties,
            PropertiesCompanion.insert(
              path: path.value,
              key: p.key,
              keyLower: p.key.toLowerCase(),
              valueType: p.valueType,
              ordinal: p.ordinal,
              valueText: Value(p.valueText),
              valueLower: Value(p.valueLower),
              valueNum: Value(p.valueNum),
              valueBool: Value(p.valueBool),
              valueDate: Value(p.valueDate),
            ),
          );
        }

        // Tasks
        for (final t in x.tasks) {
          batch.insert(
            db.tasks,
            TasksCompanion.insert(
              path: path.value,
              line: t.line,
              statusChar: t.statusChar,
              taskText: t.text,
              taskLower: t.text.toLowerCase(),
              startOffset: t.start,
              endOffset: t.end,
              due: Value(t.due),
            ),
          );
        }
      });

      _nameTable.setAliases(path, x.aliases);
      final newAliasKeys = x.aliases.map((a) => a.toLowerCase()).toList();
      return _WriteResult(oldAliasKeys, newAliasKeys);
    } else {
      _nameTable.setAliases(path, const []);
      return _WriteResult(oldAliasKeys, const []);
    }
  }

  Future<Set<String>> _deleteFile(VaultPath path) async {
    final noteRow = await (db.select(
      db.notes,
    )..where((n) => n.path.equals(path.value))).getSingleOrNull();
    if (noteRow != null) {
      await ftsDelete(db, noteRow.id);
    }

    final oldAliases = _nameTable
        .aliasesOf(path)
        .map((a) => a.toLowerCase())
        .toSet();
    await (db.delete(db.files)..where((f) => f.path.equals(path.value))).go();
    _nameTable.removeFile(path);
    _nameTable.setAliases(path, const []);

    return fileTargetKeys(path).union(oldAliases);
  }

  Future<Set<String>> _reresolve(Set<String> dirtyKeys) async {
    final keys = Set<String>.from(dirtyKeys)..remove('');
    if (keys.isEmpty) return const <String>{};

    final changedTargets = <String>{};
    final keyList = keys.toList();
    final resolver = LinkResolver(_nameTable);

    const chunkSize = 500;
    for (var i = 0; i < keyList.length; i += chunkSize) {
      final chunk = keyList.sublist(
        i,
        i + chunkSize > keyList.length ? keyList.length : i + chunkSize,
      );

      final rows = await (db.select(
        db.links,
      )..where((l) => l.targetKey.isIn(chunk))).get();

      final updates =
          <({int id, String? targetPath, bool resolved, bool viaAlias})>[];

      for (final row in rows) {
        final r = resolver.resolve(row.targetRaw, from: VaultPath(row.source));
        final newPath = r?.path.value;
        final newVia = r?.viaAlias ?? false;
        final newResolved = r != null;

        if (newPath != row.targetPath ||
            newVia != row.viaAlias ||
            newResolved != row.resolved) {
          updates.add((
            id: row.id,
            targetPath: newPath,
            resolved: newResolved,
            viaAlias: newVia,
          ));
          if (row.targetPath != null) changedTargets.add(row.targetPath!);
          if (newPath != null) changedTargets.add(newPath);
          changedTargets.add(row.source);
        }
      }

      if (updates.isNotEmpty) {
        await db.transaction(() async {
          await db.batch((batch) {
            for (final u in updates) {
              batch.update(
                db.links,
                LinksCompanion(
                  targetPath: Value(u.targetPath),
                  resolved: Value(u.resolved),
                  viaAlias: Value(u.viaAlias),
                ),
                where: (l) => l.id.equals(u.id),
              );
            }
          });
        });
      }
    }

    return changedTargets;
  }

  Future<Set<String>> _reresolveAllUnresolved() async {
    final changedTargets = <String>{};
    final rows =
        await (db.select(db.links)..where(
              (l) => l.resolved.equals(false) & l.targetKey.isNotValue(''),
            ))
            .get();

    final resolver = LinkResolver(_nameTable);
    final updates =
        <({int id, String? targetPath, bool resolved, bool viaAlias})>[];

    for (final row in rows) {
      final r = resolver.resolve(row.targetRaw, from: VaultPath(row.source));
      if (r != null) {
        updates.add((
          id: row.id,
          targetPath: r.path.value,
          resolved: true,
          viaAlias: r.viaAlias,
        ));
        changedTargets.add(r.path.value);
        changedTargets.add(row.source);
      }
    }

    if (updates.isNotEmpty) {
      await db.transaction(() async {
        await db.batch((batch) {
          for (final u in updates) {
            batch.update(
              db.links,
              LinksCompanion(
                targetPath: Value(u.targetPath),
                resolved: Value(u.resolved),
                viaAlias: Value(u.viaAlias),
              ),
              where: (l) => l.id.equals(u.id),
            );
          }
        });
      });
    }

    return changedTargets;
  }

  Set<String> _symmetricDifference(Iterable<String> a, Iterable<String> b) {
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.difference(setB).union(setB.difference(setA));
  }
}
