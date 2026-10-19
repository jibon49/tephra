// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

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
  Future<void> snapshot(
    VaultPath path,
    List<int> bytes, {
    required SnapshotReason reason,
  }) async {
    if (!isSnapshotEligible(path)) return;

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

    // Check newest snapshot to avoid duplicate identical snapshots
    final existingSnapshots = await list(path);
    if (existingSnapshots.isNotEmpty) {
      final newest = existingSnapshots.first;
      final newestBytes = await read(newest);
      if (newestBytes != null && _bytesEqual(newestBytes, bytes)) {
        return; // Skip identical
      }
    }

    // Write new snapshot: <yyyyMMddTHHmmssSSSZ>.<ext>.gz
    final now = _clock.now().toUtc();
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

    final gzipped = gzip.encode(bytes);
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
    try {
      return gzip.decode(gzipped);
    } catch (_) {
      return null;
    }
  }

  /// Prunes old snapshots according to retention rules (step 03.21).
  Future<void> prune() async {
    // Retention rules implemented in step 03.21
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
