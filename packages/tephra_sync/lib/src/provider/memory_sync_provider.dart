// © 2026 Tephra. All rights reserved.

import 'dart:collection';

import 'package:tephra_core/tephra_core.dart';

import '../errors/sync_exceptions.dart';
import 'quota.dart';
import 'remote_changes.dart';
import 'remote_object.dart';
import 'sync_provider.dart';

final class _MemoryObj {
  _MemoryObj({
    required this.bytes,
    required this.size,
    required this.modified,
    required this.created,
  });

  List<int> bytes;
  int size;
  DateTime modified;
  final DateTime created;

  RemoteObject toRemoteObject(String key) =>
      RemoteObject(key: key, size: size, modified: modified, created: created);
}

/// In-memory implementation of [SyncProvider] for pure tests and simulators.
final class MemorySyncProvider implements SyncProvider {
  /// Creates a [MemorySyncProvider].
  MemorySyncProvider({
    this.clock = const SystemClock(),
    this.id = 'memory',
    this.quotaLimitBytes,
    this.beforeOp,
  });

  /// Injected clock for deterministic timestamps.
  final Clock clock;

  @override
  final String id;

  /// Optional storage quota limit in bytes.
  int? quotaLimitBytes;

  /// Optional fault injection hook called before each operation.
  Future<void> Function(String op, String key)? beforeOp;

  final SplayTreeMap<String, _MemoryObj> _storage =
      SplayTreeMap<String, _MemoryObj>();
  final List<(int counter, String key, bool removed)> _changeLog = [];
  int _changeCounter = 0;

  @override
  Future<void> connect() async {
    if (beforeOp != null) {
      await beforeOp!('connect', '');
    }
  }

  @override
  Future<List<RemoteObject>> list(String prefix) async {
    if (beforeOp != null) {
      await beforeOp!('list', prefix);
    }
    final results = <RemoteObject>[];
    for (final entry in _storage.entries) {
      if (prefix.isEmpty || entry.key.startsWith(prefix)) {
        results.add(entry.value.toRemoteObject(entry.key));
      }
    }
    return results;
  }

  @override
  Future<List<int>> get(String key) async {
    if (beforeOp != null) {
      await beforeOp!('get', key);
    }
    validateRemoteKey(key);
    final obj = _storage[key];
    if (obj == null) {
      throw RemoteNotFoundException(key);
    }
    return List<int>.from(obj.bytes);
  }

  @override
  Future<void> put(String key, List<int> bytes) async {
    if (beforeOp != null) {
      await beforeOp!('put', key);
    }
    validateRemoteKey(key);

    if (quotaLimitBytes != null) {
      var currentUsed = 0;
      for (final o in _storage.values) {
        currentUsed += o.size;
      }
      final existing = _storage[key];
      final delta = bytes.length - (existing?.size ?? 0);
      if (currentUsed + delta > quotaLimitBytes!) {
        throw const RemoteQuotaExceededException();
      }
    }

    final now = clock.now().toUtc();
    final existing = _storage[key];
    if (existing != null) {
      existing.bytes = List<int>.from(bytes);
      existing.size = bytes.length;
      existing.modified = now;
    } else {
      _storage[key] = _MemoryObj(
        bytes: List<int>.from(bytes),
        size: bytes.length,
        modified: now,
        created: now,
      );
    }

    _changeCounter++;
    _changeLog.add((_changeCounter, key, false));
  }

  @override
  Future<void> delete(String key) async {
    if (beforeOp != null) {
      await beforeOp!('delete', key);
    }
    validateRemoteKey(key);

    if (_storage.remove(key) != null) {
      _changeCounter++;
      _changeLog.add((_changeCounter, key, true));
    }
  }

  @override
  Future<RemoteChanges> changesSince(String? cursor) async {
    if (beforeOp != null) {
      await beforeOp!('changesSince', cursor ?? '');
    }

    if (cursor == null) {
      return RemoteChanges(
        changedKeys: const [],
        removedKeys: const [],
        cursor: '$_changeCounter',
        cursorWasReset: false,
      );
    }

    final parsedCursor = int.tryParse(cursor);
    if (parsedCursor == null ||
        parsedCursor < 0 ||
        parsedCursor > _changeCounter) {
      return RemoteChanges(
        changedKeys: const [],
        removedKeys: const [],
        cursor: '$_changeCounter',
        cursorWasReset: true,
      );
    }

    final changed = <String>[];
    final removed = <String>[];
    for (final record in _changeLog) {
      if (record.$1 > parsedCursor) {
        if (record.$3) {
          if (!removed.contains(record.$2)) {
            removed.add(record.$2);
          }
        } else {
          if (!changed.contains(record.$2)) {
            changed.add(record.$2);
          }
        }
      }
    }

    return RemoteChanges(
      changedKeys: changed,
      removedKeys: removed,
      cursor: '$_changeCounter',
      cursorWasReset: false,
    );
  }

  @override
  Future<Quota?> quota() async {
    if (beforeOp != null) {
      await beforeOp!('quota', '');
    }
    var used = 0;
    for (final o in _storage.values) {
      used += o.size;
    }
    return Quota(usedBytes: used, limitBytes: quotaLimitBytes);
  }
}
