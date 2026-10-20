// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../local/sync_path_rules.dart';

/// Reason why a local history snapshot was captured.
enum SnapshotReason {
  /// Periodic snapshot captured during active editing.
  editing,

  /// Snapshot taken immediately before a remote sync cycle overwrites a file.
  beforeSyncOverwrite,

  /// Snapshot captured prior to restoring an older version.
  beforeRestore,

  /// Snapshot captured prior to resolving a conflict copy.
  beforeConflictResolution,
}

/// Manages local point-in-time snapshots in the `.tephra/history/` directory.
final class LocalHistory {
  LocalHistory(this.fs, [this._clock = const SystemClock()]);

  final VaultFileSystem fs;
  final Clock _clock;

  static final RegExp _stampRegex = RegExp(
    r'(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(\d{3})Z',
  );

  /// Parses a UTC [DateTime] from a snapshot filename or path.
  static DateTime? parseTimestamp(String snapshotRef) {
    final match = _stampRegex.firstMatch(snapshotRef);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
      int.parse(match.group(7)!),
    );
  }

  /// Returns true if [path] is a text file that should have local history snapshots.
  static bool isSnapshotEligible(VaultPath path) {
    final ext = path.extension;
    if (ext == 'md' || ext == 'txt' || ext == 'canvas' || ext == 'base') {
      return true;
    }
    return SyncPathRules.syncedTephraFiles.contains(path.value);
  }

  /// Calculates the 16-character path hash directory for [path].
  static String pathHash(VaultPath path) {
    return contentHash(utf8.encode(path.value)).substring(0, 16);
  }

  /// Takes a local history snapshot of [bytes] for [path] under [reason].
  ///
  /// Skips capture if the file is not eligible, or if identical to the newest snapshot.
  /// For [SnapshotReason.editing], also skips if the newest snapshot is younger than 10 minutes.
  Future<void> snapshot(
    VaultPath path,
    List<int> bytes, {
    required SnapshotReason reason,
  }) async {
    if (!isSnapshotEligible(path)) return;

    final now = _clock.now().toUtc();
    final hash = pathHash(path);
    final historyFolder = VaultPath('.tephra/history/$hash');

    // Ensure directory exists
    await fs.createFolder(historyFolder);

    // Write path.txt if missing
    final pathTxt = historyFolder.join('path.txt');
    final stat = await fs.stat(pathTxt);
    if (stat == null) {
      await fs.writeBytes(pathTxt, utf8.encode(path.value));
    }

    // Check existing snapshots
    final existingSnapshots = await list(path);
    if (existingSnapshots.isNotEmpty) {
      final newest = existingSnapshots.first;

      if (reason == SnapshotReason.editing) {
        final newestTime = parseTimestamp(newest);
        if (newestTime != null &&
            now.difference(newestTime) < const Duration(minutes: 10)) {
          return; // Skip: newest snapshot is younger than 10 minutes
        }
      }

      final newestBytes = await read(newest);
      if (newestBytes != null && _bytesEqual(newestBytes, bytes)) {
        return; // Skip identical
      }
    }

    // Write new snapshot: <yyyyMMddTHHmmssSSSZ>.<ext>.gz
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    final stamp = '$y$m${d}T$h$min$sec${ms}Z';

    final ext = path.extension.isEmpty ? 'txt' : path.extension;
    final fileName = '$stamp.$ext.gz';
    final snapshotPath = historyFolder.join(fileName);

    final List<int> gzipped;
    if (bytes.length > 256 * 1024) {
      gzipped = await Isolate.run(() => gzip.encode(bytes));
    } else {
      gzipped = gzip.encode(bytes);
    }

    await fs.writeBytes(snapshotPath, gzipped);
  }

  /// Lists snapshot file references for [path], ordered newest first.
  Future<List<String>> list(VaultPath path) async {
    final hash = pathHash(path);
    final historyFolder = VaultPath('.tephra/history/$hash');
    final stat = await fs.stat(historyFolder);
    if (stat == null) return const [];

    final entries = await fs.list(folder: historyFolder, recursive: false);
    final snapshots = <String>[];
    for (final e in entries) {
      if (e.path.value.endsWith('.gz')) {
        snapshots.add(e.path.value);
      }
    }
    // Sort descending by timestamp in filename
    snapshots.sort((a, b) => b.compareTo(a));
    return snapshots;
  }

  /// Reads and decompresses snapshot content for [snapshotRef].
  Future<List<int>?> read(String snapshotRef) async {
    final vp = VaultPath(snapshotRef);
    final stat = await fs.stat(vp);
    if (stat == null) return null;

    final gzipped = await fs.readBytes(vp);
    if (gzipped.length > 256 * 1024) {
      return Isolate.run(() {
        try {
          return gzip.decode(gzipped);
        } catch (_) {
          return null;
        }
      });
    }

    try {
      return gzip.decode(gzipped);
    } catch (_) {
      return null;
    }
  }

  /// Prunes old snapshots according to retention rules (step 03.21).
  ///
  /// - Keeps all snapshots younger than 7 days.
  /// - Between 7 and 30 days keeps the newest per calendar day (UTC).
  /// - Deletes older than 30 days (except the newest snapshot of each path).
  /// - Always keeps the newest snapshot of any path.
  /// - If total size of `.tephra/history/` exceeds [maxHistoryBytes] (100 MiB),
  ///   deletes oldest snapshots until below (never deleting the newest of any path).
  Future<void> prune({int maxHistoryBytes = 100 * 1024 * 1024}) async {
    final historyRoot = VaultPath('.tephra/history');
    final stat = await fs.stat(historyRoot);
    if (stat == null) return;

    final entries = await fs.list(folder: historyRoot, recursive: true);
    final gzFiles = entries
        .where((e) => !e.isFolder && e.path.value.endsWith('.gz'))
        .toList();
    if (gzFiles.isEmpty) return;

    final now = _clock.now().toUtc();

    // Group snapshots by folder (pathHash)
    final byFolder = <String, List<VaultEntry>>{};
    for (final e in gzFiles) {
      final parentFolder = e.path.parent?.value ?? '';
      byFolder.putIfAbsent(parentFolder, () => []).add(e);
    }

    final keptSnapshots = <VaultEntry>[];

    for (final folderSnapshots in byFolder.values) {
      // Sort newest first
      folderSnapshots.sort((a, b) => b.path.value.compareTo(a.path.value));

      final newestSnapshot = folderSnapshots.first;
      keptSnapshots.add(newestSnapshot);

      final calendarDaysKept = <String>{};
      final newestTime = parseTimestamp(newestSnapshot.path.value);
      if (newestTime != null) {
        final age = now.difference(newestTime);
        if (age >= const Duration(days: 7) && age <= const Duration(days: 30)) {
          calendarDaysKept.add(
            '${newestTime.year}-${newestTime.month}-${newestTime.day}',
          );
        }
      }

      for (var i = 1; i < folderSnapshots.length; i++) {
        final entry = folderSnapshots[i];
        final stamp = parseTimestamp(entry.path.value);
        if (stamp == null) {
          await fs.delete(entry.path, mode: TrashMode.permanent);
          continue;
        }

        final age = now.difference(stamp);
        if (age < const Duration(days: 7)) {
          keptSnapshots.add(entry);
        } else if (age <= const Duration(days: 30)) {
          final dayKey = '${stamp.year}-${stamp.month}-${stamp.day}';
          if (calendarDaysKept.add(dayKey)) {
            keptSnapshots.add(entry);
          } else {
            await fs.delete(entry.path, mode: TrashMode.permanent);
          }
        } else {
          await fs.delete(entry.path, mode: TrashMode.permanent);
        }
      }
    }

    final remainingEntries = await fs.list(
      folder: historyRoot,
      recursive: true,
    );
    var totalBytes = 0;
    final deletable = <VaultEntry>[];
    final newestPaths = byFolder.values
        .map((list) => list.first.path.value)
        .toSet();

    for (final e in remainingEntries) {
      if (!e.isFolder) {
        totalBytes += e.size;
        if (e.path.value.endsWith('.gz') &&
            !newestPaths.contains(e.path.value)) {
          deletable.add(e);
        }
      }
    }

    if (totalBytes > maxHistoryBytes) {
      // Sort oldest first (ascending by timestamp/path)
      deletable.sort((a, b) => a.path.value.compareTo(b.path.value));

      for (final e in deletable) {
        if (totalBytes <= maxHistoryBytes) break;
        await fs.delete(e.path, mode: TrashMode.permanent);
        totalBytes -= e.size;
      }
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
