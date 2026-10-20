// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../reading/parse_service.dart';
import 'note_document.dart';

final _logger = Logger('NoteDocumentStore');

final class NoteDocumentStore {
  NoteDocumentStore(
    this.fs,
    this.clock, {
    this.parseService = const ParseService(),
    this.onFlushed,
    LocalHistory? localHistory,
  }) : localHistory = localHistory ?? LocalHistory(fs, clock);

  final VaultFileSystem fs;
  final Clock clock;
  final ParseService parseService;
  final LocalHistory localHistory;
  VoidCallback? onFlushed;

  final Map<VaultPath, NoteDocument> _documents = {};
  final Map<VaultPath, int> _refCounts = {};

  final ValueNotifier<int> _stateVersion = ValueNotifier<int>(0);
  ValueListenable<int> get stateVersion => _stateVersion;

  StreamSubscription<VaultChange>? _watchSub;
  bool _isDisposed = false;

  void start() {
    _watchSub?.cancel();
    _watchSub = fs.watch().listen(
      (change) {
        if (_isDisposed) return;
        if (change is FileCreated || change is FileModified) {
          final doc = peek(change.path);
          if (doc != null) {
            doc.onExternalChange().catchError((Object e, StackTrace s) {
              _logger.warning(
                'Failed to handle external change for ${change.path}: $e',
                e,
                s,
              );
            });
          }
        } else if (change is FileDeleted) {
          final doc = peek(change.path);
          if (doc != null) {
            doc.onExternalDelete().catchError((Object e, StackTrace s) {
              _logger.warning(
                'Failed to handle external delete for ${change.path}: $e',
                e,
                s,
              );
            });
          }
        }
      },
      onError: (Object e) {
        _logger.warning('Watcher stream error in NoteDocumentStore: $e');
      },
    );
  }

  void _onDocChanged() {
    if (!_isDisposed) {
      _stateVersion.value++;
    }
  }

  NoteDocument acquire(VaultPath path) {
    final existing = _documents[path];
    if (existing != null) {
      _refCounts[path] = (_refCounts[path] ?? 0) + 1;
      return existing;
    }

    final doc = NoteDocument(
      path: path,
      fs: fs,
      clock: clock,
      parseService: parseService,
      localHistory: localHistory,
      onDiskChanged: _onDocChanged,
      onDocChanged: _onDocChanged,
    );
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
    final dirty = _documents.values.where((d) => d.isDirty).toList();
    if (dirty.isNotEmpty) {
      await Future.wait(dirty.map((d) => d.save()));
    }
    onFlushed?.call();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _watchSub?.cancel();
    _stateVersion.dispose();
    for (final doc in _documents.values) {
      doc.dispose();
    }
    _documents.clear();
    _refCounts.clear();
  }
}
