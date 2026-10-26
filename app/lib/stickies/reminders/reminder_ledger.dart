// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tephra_core/tephra_core.dart';

/// Single entry in [ReminderLedger] recording what notification was scheduled.
@immutable
final class ReminderEntry {
  const ReminderEntry({required this.path, required this.at});

  final VaultPath path;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'path': path.value,
    'at': at.toUtc().toIso8601String(),
  };

  static ReminderEntry? fromJson(Map<String, Object?> json) {
    final rawPath = json['path'] as String?;
    final rawAt = json['at'] as String?;
    if (rawPath == null || rawAt == null) return null;
    final parsedAt = DateTime.tryParse(rawAt);
    if (parsedAt == null) return null;
    try {
      return ReminderEntry(path: VaultPath(rawPath), at: parsedAt.toUtc());
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderEntry &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          at.toUtc().isAtSameMomentAs(other.at.toUtc());

  @override
  int get hashCode => Object.hash(path, at.toUtc().millisecondsSinceEpoch);
}

/// Ledger tracking scheduled reminders per vault across restarts.
abstract interface class ReminderLedger {
  Map<int, ReminderEntry> getEntries(String vaultId);
  Future<void> saveEntries(String vaultId, Map<int, ReminderEntry> entries);
}

/// In-memory ledger implementation for unit tests.
class MemoryReminderLedger implements ReminderLedger {
  MemoryReminderLedger([Map<String, Map<int, ReminderEntry>>? initial])
    : _store = initial != null
          ? {
              for (final e in initial.entries)
                e.key: Map<int, ReminderEntry>.from(e.value),
            }
          : {};

  final Map<String, Map<int, ReminderEntry>> _store;

  @override
  Map<int, ReminderEntry> getEntries(String vaultId) {
    final map = _store[vaultId];
    return map != null ? Map.unmodifiable(map) : const {};
  }

  @override
  Future<void> saveEntries(
    String vaultId,
    Map<int, ReminderEntry> entries,
  ) async {
    _store[vaultId] = Map<int, ReminderEntry>.from(entries);
  }
}

/// File-backed ledger persisting to `<appSupportDir>/reminders.json`.
class FileReminderLedger implements ReminderLedger {
  FileReminderLedger(this.file);

  final File file;
  final Map<String, Map<int, ReminderEntry>> _cache = {};
  bool _loaded = false;

  Future<void> load() async {
    if (!file.existsSync()) {
      _loaded = true;
      return;
    }
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, Object?>) {
        _parseJson(decoded);
      }
    } catch (_) {
      _cache.clear();
    }
    _loaded = true;
  }

  void _parseJson(Map<String, Object?> json) {
    _cache.clear();
    for (final vaultEntry in json.entries) {
      final vaultId = vaultEntry.key;
      final rawEntries = vaultEntry.value;
      if (rawEntries is! Map) continue;
      final map = <int, ReminderEntry>{};
      for (final e in rawEntries.entries) {
        final id = int.tryParse(e.key.toString());
        if (id == null) continue;
        if (e.value is! Map) continue;
        final entry = ReminderEntry.fromJson(
          Map<String, Object?>.from(e.value as Map),
        );
        if (entry != null) {
          map[id] = entry;
        }
      }
      _cache[vaultId] = map;
    }
  }

  @override
  Map<int, ReminderEntry> getEntries(String vaultId) {
    if (!_loaded && file.existsSync()) {
      try {
        final text = file.readAsStringSync();
        final decoded = jsonDecode(text);
        if (decoded is Map<String, Object?>) {
          _parseJson(decoded);
        }
      } catch (_) {
        _cache.clear();
      }
      _loaded = true;
    }
    final map = _cache[vaultId];
    return map != null ? Map.unmodifiable(map) : const {};
  }

  @override
  Future<void> saveEntries(
    String vaultId,
    Map<int, ReminderEntry> entries,
  ) async {
    if (!_loaded) {
      await load();
    }
    _cache[vaultId] = Map<int, ReminderEntry>.from(entries);

    final parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }

    final out = <String, Object?>{};
    for (final vault in _cache.entries) {
      final vaultMap = <String, Object?>{};
      for (final entry in vault.value.entries) {
        vaultMap[entry.key.toString()] = entry.value.toJson();
      }
      out[vault.key] = vaultMap;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(out);
    final tmpFile = File(
      '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await tmpFile.writeAsString(jsonString, flush: true);
      if (!kIsWeb && Platform.isWindows && file.existsSync()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
    } finally {
      if (tmpFile.existsSync()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }
}
