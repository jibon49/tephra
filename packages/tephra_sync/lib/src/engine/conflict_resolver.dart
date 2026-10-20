// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../history/local_history.dart';
import '../model/conflict_record.dart';
import '../model/sync_log_entry.dart';
import '../store/sync_state_store.dart';

/// Available resolution choices for a conflict copy.
enum ConflictResolution {
  /// Keep the local version (the conflict copy): overwrites the main file with
  /// the copy's content, and moves the conflict copy to vault trash.
  keepMine,

  /// Keep the remote version (the main file): moves the conflict copy to vault trash.
  keepTheirs,

  /// Keep both versions: retains both files on disk without modifying either.
  keepBoth,

  /// Custom edit merge: writes user-edited text to the main file, and moves
  /// the conflict copy to vault trash.
  editMerge;

  /// Compatibility alias for [keepMine].
  static const ConflictResolution keepLocal = keepMine;

  /// Compatibility alias for [keepTheirs].
  static const ConflictResolution keepRemote = keepTheirs;

  /// Compatibility alias for [editMerge].
  static const ConflictResolution custom = editMerge;
}

/// Resolves synchronization conflict copies safely without data loss.
///
/// Every destructive or overwrite action creates a local history snapshot first,
/// moves old copies to `.trash/`, records resolutions in the sync state database,
/// and writes descriptive audit log entries.
final class ConflictResolver {
  /// Creates a [ConflictResolver].
  ConflictResolver({
    required this.fs,
    required this.store,
    required this.localHistory,
    this.clock = const SystemClock(),
  });

  /// The active vault filesystem.
  final VaultFileSystem fs;

  /// Database store holding conflict records and sync logs.
  final SyncStateStore store;

  /// Local point-in-time snapshot manager.
  final LocalHistory localHistory;

  /// Clock used for audit log timestamps.
  final Clock clock;

  /// Resolves the conflict record identified by [conflictId] using [resolution].
  ///
  /// For [ConflictResolution.editMerge], [mergedText] must contain the merged content.
  Future<void> resolve({
    required int conflictId,
    required ConflictResolution resolution,
    String? mergedText,
  }) async {
    final conflicts = await store.conflicts();
    ConflictRecord? target;
    for (final c in conflicts) {
      if (c.id == conflictId) {
        target = c;
        break;
      }
    }

    if (target == null) {
      throw SyncException('Conflict record $conflictId not found');
    }

    if (target.resolved) {
      return;
    }

    final mainPath = VaultPath(target.path);
    final copyPath = VaultPath(target.copyPath);
    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;

    switch (resolution) {
      case ConflictResolution.keepMine:
        // 1. Snapshot both into local history
        if (await fs.stat(mainPath) != null) {
          final mainBytes = await fs.readBytes(mainPath);
          await localHistory.snapshot(
            mainPath,
            mainBytes,
            reason: SnapshotReason.beforeConflictResolution,
          );
        }
        if (await fs.stat(copyPath) != null) {
          final copyBytes = await fs.readBytes(copyPath);
          await localHistory.snapshot(
            copyPath,
            copyBytes,
            reason: SnapshotReason.beforeConflictResolution,
          );
          // 2. Write copy content to main path (normal edit -> will be synced)
          await fs.writeBytes(mainPath, copyBytes);
          // 3. Move conflict copy to vault trash
          await fs.delete(copyPath, mode: TrashMode.vaultTrash);
        }

        await store.resolveConflict(conflictId);
        await store.appendLog(
          SyncLogEntry(
            time: nowMs,
            level: 'info',
            kind: 'conflictResolved',
            path: target.path,
            otherPath: target.copyPath,
            detail: 'Resolved conflict: kept mine',
          ),
        );

      case ConflictResolution.keepTheirs:
        // 1. Snapshot copy into local history
        if (await fs.stat(copyPath) != null) {
          final copyBytes = await fs.readBytes(copyPath);
          await localHistory.snapshot(
            copyPath,
            copyBytes,
            reason: SnapshotReason.beforeConflictResolution,
          );
          // 2. Move conflict copy to vault trash
          await fs.delete(copyPath, mode: TrashMode.vaultTrash);
        }

        await store.resolveConflict(conflictId);
        await store.appendLog(
          SyncLogEntry(
            time: nowMs,
            level: 'info',
            kind: 'conflictResolved',
            path: target.path,
            otherPath: target.copyPath,
            detail: 'Resolved conflict: kept theirs',
          ),
        );

      case ConflictResolution.keepBoth:
        // Files stay as they are. Mark resolved.
        await store.resolveConflict(conflictId);
        await store.appendLog(
          SyncLogEntry(
            time: nowMs,
            level: 'info',
            kind: 'conflictResolved',
            path: target.path,
            otherPath: target.copyPath,
            detail: 'Resolved conflict: kept both',
          ),
        );

      case ConflictResolution.editMerge:
        // 1. Snapshot both into local history
        if (await fs.stat(mainPath) != null) {
          final mainBytes = await fs.readBytes(mainPath);
          await localHistory.snapshot(
            mainPath,
            mainBytes,
            reason: SnapshotReason.beforeConflictResolution,
          );
        }
        final copyExists = await fs.stat(copyPath) != null;
        if (copyExists) {
          final copyBytes = await fs.readBytes(copyPath);
          await localHistory.snapshot(
            copyPath,
            copyBytes,
            reason: SnapshotReason.beforeConflictResolution,
          );
        }

        // 2. Write merged text to main path
        await fs.writeText(mainPath, TextDocument(text: mergedText ?? ''));

        // 3. Move conflict copy to vault trash
        if (copyExists) {
          await fs.delete(copyPath, mode: TrashMode.vaultTrash);
        }

        await store.resolveConflict(conflictId);
        await store.appendLog(
          SyncLogEntry(
            time: nowMs,
            level: 'info',
            kind: 'conflictResolved',
            path: target.path,
            otherPath: target.copyPath,
            detail: 'Resolved conflict: edited merge',
          ),
        );
    }
  }

  /// Automatically marks conflict records resolved if their conflict copy file
  /// has been deleted or moved outside this resolution flow.
  ///
  /// Returns the number of conflict records automatically resolved.
  Future<int> autoResolveDisappeared() async {
    final unresolved = await store.conflicts(unresolvedOnly: true);
    var resolvedCount = 0;
    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;

    for (final record in unresolved) {
      final copyPath = VaultPath(record.copyPath);
      final exists = await fs.stat(copyPath) != null;
      if (!exists) {
        await store.resolveConflict(record.id!);
        await store.appendLog(
          SyncLogEntry(
            time: nowMs,
            level: 'info',
            kind: 'conflictResolved',
            path: record.path,
            otherPath: record.copyPath,
            detail:
                'Conflict copy ${record.copyPath} was removed; automatically marked resolved',
          ),
        );
        resolvedCount++;
      }
    }

    return resolvedCount;
  }
}
