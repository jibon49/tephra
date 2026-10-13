// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'note_document.dart';

final class NoteDocumentStore {
  NoteDocumentStore(this.fs, this.clock);

  final VaultFileSystem fs;
  final Clock clock;

  final Map<VaultPath, NoteDocument> _documents = {};
  final Map<VaultPath, int> _refCounts = {};

  NoteDocument acquire(VaultPath path) {
    final existing = _documents[path];
    if (existing != null) {
      _refCounts[path] = (_refCounts[path] ?? 0) + 1;
      return existing;
    }

    final doc = NoteDocument(path: path, fs: fs, clock: clock);
    _documents[path] = doc;
    _refCounts[path] = 1;
    unawaited(doc.load());
    return doc;
  }

  void release(VaultPath path) {
    final count = (_refCounts[path] ?? 0) - 1;
    if (count <= 0) {
      _refCounts.remove(path);
      final doc = _documents.remove(path);
      if (doc != null) {
        if (doc.isDirty) {
          unawaited(doc.save().then((_) => doc.dispose()));
        } else {
          doc.dispose();
        }
      }
    } else {
      _refCounts[path] = count;
    }
  }

  NoteDocument? peek(VaultPath path) => _documents[path];

  Iterable<NoteDocument> get open => _documents.values;

  Future<void> flushPath(VaultPath pathOrFolder) async {
    for (final doc in List.of(_documents.values)) {
      if (doc.path == pathOrFolder || doc.path.isWithin(pathOrFolder)) {
        if (doc.isDirty) {
          await doc.save();
        }
      }
    }
  }

  void retargetPath(VaultPath from, VaultPath to) {
    final entries = List.of(_documents.entries);
    for (final entry in entries) {
      final oldPath = entry.key;
      final doc = entry.value;

      VaultPath? newPath;
      if (oldPath == from) {
        newPath = to;
      } else if (oldPath.isWithin(from)) {
        final relSuffix = from.isRoot
            ? oldPath.value
            : oldPath.value.substring(from.value.length + 1);
        newPath = to.isRoot ? VaultPath(relSuffix) : to.join(relSuffix);
      }

      if (newPath != null) {
        final count = _refCounts.remove(oldPath) ?? 1;
        _documents.remove(oldPath);

        doc.path = newPath;
        _documents[newPath] = doc;
        _refCounts[newPath] = count;
      }
    }
  }

  void discardPath(VaultPath pathOrFolder) {
    final paths = List.of(_documents.keys);
    for (final p in paths) {
      if (p == pathOrFolder || p.isWithin(pathOrFolder)) {
        _refCounts.remove(p);
        final doc = _documents.remove(p);
        doc?.dispose();
      }
    }
  }

  Future<void> flushAll() async {
    for (final doc in List.of(_documents.values)) {
      if (doc.isDirty) {
        await doc.save();
      }
    }
  }
}
