// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Decorator for [VaultFileSystem] that reports all successful write, move,
/// and delete operations to an attached index sink.
final class IndexingVaultFileSystem implements VaultFileSystem {
  IndexingVaultFileSystem(this._inner);

  final VaultFileSystem _inner;
  final _log = Logger('index');
  void Function(VaultChange)? _sink;
  final List<VaultChange> _pending = [];

  /// The underlying undecorated file system.
  VaultFileSystem get inner => _inner;

  /// Attaches the index sink. Any pending changes that occurred before
  /// attachment are flushed in order.
  void attachIndex(void Function(VaultChange) sink) {
    _sink = sink;
    if (_pending.isNotEmpty) {
      final toFlush = List<VaultChange>.from(_pending);
      _pending.clear();
      for (final change in toFlush) {
        _report(change);
      }
    }
  }

  void _report(VaultChange change) {
    final sink = _sink;
    if (sink == null) {
      _pending.add(change);
    } else {
      try {
        sink(change);
      } catch (err, st) {
        _log.warning('Failed to report change to index sink: $change', err, st);
      }
    }
  }

  @override
  String get rootDisplayPath => _inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) {
    return _inner.list(folder: folder, recursive: recursive);
  }

  @override
  Future<VaultEntry?> stat(VaultPath path) {
    return _inner.stat(path);
  }

  @override
  Future<List<int>> readBytes(VaultPath path) {
    return _inner.readBytes(path);
  }

  @override
  Future<TextDocument> readText(VaultPath path) {
    return _inner.readText(path);
  }

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) async {
    await _inner.writeBytes(path, bytes);
    _report(FileModified(path));
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) async {
    await _inner.writeText(path, doc);
    _report(FileModified(path));
  }

  @override
  Future<void> createFolder(VaultPath path) {
    return _inner.createFolder(path);
  }

  @override
  Future<void> move(VaultPath from, VaultPath to) async {
    await _inner.move(from, to);
    _report(FileMoved(to, from: from));
  }

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) async {
    await _inner.delete(path, mode: mode);
    _report(FileDeleted(path));
  }

  @override
  Stream<VaultChange> watch() => _inner.watch();

  @override
  Future<void> dispose() => _inner.dispose();
}
