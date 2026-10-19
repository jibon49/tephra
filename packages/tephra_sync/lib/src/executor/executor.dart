// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../blobs/blob_store.dart';
import '../history/local_history.dart';
import '../merge/conflict_naming.dart';
import '../merge/frontmatter_merge.dart';
import '../merge/json_merge.dart';
import '../merge/merge_kind.dart';
import '../merge/three_way_merge.dart';
import '../model/base_state.dart';
import '../model/conflict_record.dart';
import '../model/journal_entry.dart';
import '../model/sync_log_entry.dart';
import '../planner/sync_action.dart';
import '../remote/journal_writer.dart';
import '../store/sync_state_store.dart';
import 'crash_injector.dart';
import 'editor_guard.dart';

final _logger = Logger('Executor');

/// Execution outcome status for an individual [SyncAction].
enum ExecutionStatus {
  applied,
  alreadyApplied,
  skippedPrecondition,
  skippedEditorGuard,
  failed,
}

/// The result of executing a single [SyncAction].
final class ExecutionResult {
  const ExecutionResult({
    required this.status,
    required this.action,
    this.bytesDown = 0,
    this.bytesUp = 0,
    this.errorMessage,
    this.stagedUploads = const [],
  });

  final ExecutionStatus status;
  final SyncAction action;
  final int bytesDown;
  final int bytesUp;
  final String? errorMessage;
  final List<Upload> stagedUploads;
}

/// Carries out planned synchronization actions with strict idempotency,
/// preconditions, crash safety, and local history capture.
final class Executor {
  Executor({
    required this.fs,
    required this.store,
    required this.blobStore,
    required this.journalWriter,
    required this.deviceName,
    this.editorGuard = const AllowAllEditorGuard(),
    this.localHistory,
    this.crashInjector,
    this.clock = const SystemClock(),
    this.caseInsensitive = false,
    Random? random,
  }) : _random = random ?? Random();

  final VaultFileSystem fs;
  final SyncStateStore store;
  final BlobStore blobStore;
  final JournalWriter journalWriter;
  final String deviceName;
  final EditorGuard editorGuard;
  final LocalHistory? localHistory;
  final CrashInjector? crashInjector;
  final Clock clock;
  final bool caseInsensitive;
  final Random _random;

  /// Executes [action] and returns an [ExecutionResult].
  Future<ExecutionResult> execute(SyncAction action) async {
    return switch (action) {
      final RenameLocal a => _executeRenameLocal(a),
      final DeleteLocal a => _executeDeleteLocal(a),
      final Download a => _executeDownload(a),
      final Merge a => _executeMerge(a),
      final ConflictCopy a => _executeConflictCopy(a),
      final Upload a => _executeUpload(a),
      final RenameRemote a => _executeRenameRemote(a),
      final DeleteRemote a => _executeDeleteRemote(a),
    };
  }

  // ---------------------------------------------------------------------------
  // Phase 1: RenameLocal
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeRenameLocal(RenameLocal action) async {
    final isCaseOnly = action.path.caseKey == action.to.caseKey;
    final toStat = await fs.stat(action.to);
    if (toStat != null) {
      final toBytes = await fs.readBytes(action.to);
      final toHash = contentHash(toBytes);
      if (toHash == action.expectedHash) {
        // For case-only rename, already applied only if on-disk casing matches target
        if (!isCaseOnly || toStat.path.name == action.to.name) {
          await _updateBaseAfterRename(action);
          return ExecutionResult(
            status: ExecutionStatus.alreadyApplied,
            action: action,
          );
        }
      }
    }

    final fromStat = await fs.stat(action.path);
    if (fromStat == null) {
      _logger.fine(
        'Precondition mismatch: source missing for rename ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    final fromBytes = await fs.readBytes(action.path);
    final fromHash = contentHash(fromBytes);
    if (fromHash != action.expectedHash) {
      _logger.fine(
        'Precondition mismatch: source hash $fromHash != ${action.expectedHash} for rename ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    // Precondition satisfied
    crashInjector?.call(CrashPoint.beforeLocalWrite, action.path);

    if (action.path.caseKey == action.to.caseKey) {
      // Case-only rename: <from> -> <from>.tephra-case-<8hex> -> <to>
      final hex = _randomHex(8);
      final tmp = VaultPath.raw('${action.path.value}.tephra-case-$hex');
      await fs.move(action.path, tmp);
      await fs.move(tmp, action.to);
    } else if (toStat != null) {
      // Collision at destination: preserve from as conflict copy
      final now = clock.now().toUtc();
      final copyStr = conflictCopyName(
        action.to,
        now,
        deviceName,
        (p) => p.value == action.to.value,
      );
      final copyPath = VaultPath.raw(copyStr);
      await fs.move(action.path, copyPath);
      await store.appendLog(
        SyncLogEntry(
          time: now.millisecondsSinceEpoch,
          level: 'warning',
          kind: 'renamedLocal',
          path: action.path.value,
          otherPath: copyPath.value,
          deviceName: deviceName,
          detail: 'Destination occupied; moved to conflict copy',
        ),
      );
    } else {
      await fs.move(action.path, action.to);
    }

    crashInjector?.call(CrashPoint.afterLocalWrite, action.to);

    await _updateBaseAfterRename(action);
    crashInjector?.call(CrashPoint.afterLocalStateUpdate, action.to);

    await store.appendLog(
      SyncLogEntry(
        time: clock.now().toUtc().millisecondsSinceEpoch,
        level: 'info',
        kind: 'renamedLocal',
        path: action.path.value,
        otherPath: action.to.value,
        deviceName: deviceName,
        detail: 'Renamed local file',
      ),
    );

    return ExecutionResult(status: ExecutionStatus.applied, action: action);
  }

  Future<void> _updateBaseAfterRename(RenameLocal action) async {
    final oldBase = await store.base(action.path.value);
    final remoteEntry = await store.entry(action.remoteEntryId);
    final stat = await fs.stat(action.to);
    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;

    await store.transaction(() async {
      List<String> blobKeys = const [];
      String version = action.remoteEntryId;
      if (remoteEntry != null && remoteEntry.hash == action.expectedHash) {
        version = remoteEntry.id;
        blobKeys = remoteEntry.blobKeys ?? const [];
      } else if (oldBase != null && oldBase.hash == action.expectedHash) {
        version = oldBase.version;
        blobKeys = oldBase.blobKeys;
      }

      await store.removeBase(action.path.value);
      await store.putBase(
        BaseState(
          path: action.to.value,
          caseKey: action.to.caseKey,
          hash: action.expectedHash,
          size: stat?.size ?? oldBase?.size ?? 0,
          mtime: stat?.modified.millisecondsSinceEpoch ?? oldBase?.mtime ?? 0,
          version: version,
          blobKeys: blobKeys,
          syncedAt: nowMs,
        ),
      );

      final oldBaseText = await store.baseText(action.path.value);
      if (oldBaseText != null) {
        await store.removeBaseText(action.path.value);
        await store.putBaseText(
          action.to.value,
          action.expectedHash,
          oldBaseText,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Phase 2: DeleteLocal
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeDeleteLocal(DeleteLocal action) async {
    final stat = await fs.stat(action.path);
    if (stat == null) {
      // Already absent; target state reached
      await store.removeBase(action.path.value);
      return ExecutionResult(
        status: ExecutionStatus.alreadyApplied,
        action: action,
      );
    }

    final currentBytes = await fs.readBytes(action.path);
    final currentHash = contentHash(currentBytes);
    if (currentHash != action.expectedHash) {
      _logger.fine(
        'Precondition mismatch: local hash $currentHash != ${action.expectedHash} for delete ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    crashInjector?.call(CrashPoint.beforeLocalWrite, action.path);
    await fs.delete(action.path, mode: TrashMode.vaultTrash);
    crashInjector?.call(CrashPoint.afterLocalWrite, action.path);

    await store.removeBase(action.path.value);
    crashInjector?.call(CrashPoint.afterLocalStateUpdate, action.path);

    await store.appendLog(
      SyncLogEntry(
        time: clock.now().toUtc().millisecondsSinceEpoch,
        level: 'info',
        kind: 'deletedLocal',
        path: action.path.value,
        deviceName: deviceName,
        detail: 'Deleted local file to vault trash',
      ),
    );

    return ExecutionResult(status: ExecutionStatus.applied, action: action);
  }

  // ---------------------------------------------------------------------------
  // Phase 3: Download
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeDownload(Download action) async {
    final stat = await fs.stat(action.path);
    List<int>? currentBytes;

    if (stat != null) {
      currentBytes = await fs.readBytes(action.path);
      final currentHash = contentHash(currentBytes);
      if (currentHash == action.entry.hash) {
        // Target content already written
        await _updateBaseForEntry(action.path, action.entry);
        return ExecutionResult(
          status: ExecutionStatus.alreadyApplied,
          action: action,
        );
      }

      if (action.expectedLocalHash == null ||
          currentHash != action.expectedLocalHash) {
        _logger.fine(
          'Precondition mismatch: local hash $currentHash != ${action.expectedLocalHash} for download ${action.path.value}',
        );
        return ExecutionResult(
          status: ExecutionStatus.skippedPrecondition,
          action: action,
        );
      }
    } else {
      if (action.expectedLocalHash != null) {
        _logger.fine(
          'Precondition mismatch: expected existing file for download ${action.path.value}',
        );
        return ExecutionResult(
          status: ExecutionStatus.skippedPrecondition,
          action: action,
        );
      }
    }

    // Retrieve and verify blobs
    final bytes = await blobStore.getFile(
      action.entry.blobKeys!,
      expectedPlainHash: action.entry.hash!,
    );

    // EditorGuard check if file existed
    if (stat != null) {
      final allowed = await editorGuard.mayReplace(
        action.path,
        action.expectedLocalHash ?? '',
      );
      if (!allowed) {
        _logger.fine('EditorGuard skipped replacement of ${action.path.value}');
        return ExecutionResult(
          status: ExecutionStatus.skippedEditorGuard,
          action: action,
        );
      }

      if (localHistory != null && currentBytes != null) {
        await localHistory!.snapshot(
          action.path,
          currentBytes,
          reason: SnapshotReason.beforeSyncOverwrite,
        );
      }
    }

    crashInjector?.call(CrashPoint.beforeLocalWrite, action.path);
    await fs.writeBytes(action.path, bytes);
    crashInjector?.call(CrashPoint.afterLocalWrite, action.path);

    await _updateBaseForEntry(action.path, action.entry);
    crashInjector?.call(CrashPoint.afterLocalStateUpdate, action.path);

    if (kindOf(action.path) != MergeKind.binary) {
      final text = utf8.decode(bytes, allowMalformed: true);
      await store.putBaseText(action.path.value, action.entry.hash!, text);
    }

    await store.appendLog(
      SyncLogEntry(
        time: clock.now().toUtc().millisecondsSinceEpoch,
        level: 'info',
        kind: 'downloaded',
        path: action.path.value,
        deviceName: action.entry.deviceId,
        detail: 'Downloaded remote content',
      ),
    );

    return ExecutionResult(
      status: ExecutionStatus.applied,
      action: action,
      bytesDown: bytes.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 4: Merge
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeMerge(Merge action) async {
    final stat = await fs.stat(action.path);
    if (stat == null) {
      _logger.fine(
        'Precondition mismatch: local file missing for merge ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    final localBytes = await fs.readBytes(action.path);
    final currentLocalHash = contentHash(localBytes);
    if (currentLocalHash != action.localHash) {
      _logger.fine(
        'Precondition mismatch: local hash $currentLocalHash != ${action.localHash} for merge ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    // Retrieve remote bytes
    final remoteBytes = await blobStore.getFile(
      action.remote.blobKeys!,
      expectedPlainHash: action.remote.hash!,
    );

    // Retrieve base content
    List<int>? baseBytes;
    final storedBaseText = await store.baseText(action.basePath.value);
    if (storedBaseText != null) {
      baseBytes = utf8.encode(storedBaseText);
    } else if (action.baseEntryId != null) {
      final baseEntry = await store.entry(action.baseEntryId!);
      if (baseEntry != null &&
          baseEntry.blobKeys != null &&
          baseEntry.hash != null) {
        try {
          baseBytes = await blobStore.getFile(
            baseEntry.blobKeys!,
            expectedPlainHash: baseEntry.hash!,
          );
        } catch (_) {
          baseBytes = null;
        }
      }
    }

    MergeOutcome outcome = const MergeOutcome.conflict();
    if (baseBytes != null) {
      outcome = switch (action.kind) {
        MergeKind.markdown => mergeDocuments(
          baseBytes: baseBytes,
          localBytes: localBytes,
          remoteBytes: remoteBytes,
          textMerger: mergeMarkdown,
        ),
        MergeKind.jsonObject => mergeDocuments(
          baseBytes: baseBytes,
          localBytes: localBytes,
          remoteBytes: remoteBytes,
          textMerger: mergeJson,
        ),
        MergeKind.plainText => mergeDocuments(
          baseBytes: baseBytes,
          localBytes: localBytes,
          remoteBytes: remoteBytes,
          textMerger: merge3,
        ),
        MergeKind.binary => const MergeOutcome.conflict(),
      };
    }

    if (outcome.isClean && (outcome.bytes != null || outcome.text != null)) {
      final mergedBytes = outcome.bytes ?? utf8.encode(outcome.text!);

      final allowed = await editorGuard.mayReplace(
        action.path,
        action.localHash,
      );
      if (!allowed) {
        return ExecutionResult(
          status: ExecutionStatus.skippedEditorGuard,
          action: action,
        );
      }

      if (localHistory != null) {
        await localHistory!.snapshot(
          action.path,
          localBytes,
          reason: SnapshotReason.beforeSyncOverwrite,
        );
      }

      crashInjector?.call(CrashPoint.beforeLocalWrite, action.path);
      await fs.writeBytes(action.path, mergedBytes);
      crashInjector?.call(CrashPoint.afterLocalWrite, action.path);

      final mergedHash = contentHash(mergedBytes);
      if (outcome.text != null) {
        await store.putBaseText(action.path.value, mergedHash, outcome.text!);
      }

      final stagedUpload = Upload(
        action.path,
        localHash: mergedHash,
        parent: action.remote.id,
        mergedParent: action.mergedParent,
      );

      await store.appendLog(
        SyncLogEntry(
          time: clock.now().toUtc().millisecondsSinceEpoch,
          level: 'info',
          kind: 'merged',
          path: action.path.value,
          deviceName: action.remote.deviceId,
          detail: 'Merged changes cleanly',
        ),
      );

      return ExecutionResult(
        status: ExecutionStatus.applied,
        action: action,
        bytesDown: remoteBytes.length,
        stagedUploads: [stagedUpload],
      );
    } else {
      // Conflicted or base unavailable: behave exactly like ConflictCopy
      return _executeConflictCopy(
        ConflictCopy(
          action.path,
          localHash: action.localHash,
          remote: action.remote,
          mergedParent: action.mergedParent,
        ),
        preloadedLocalBytes: localBytes,
        preloadedRemoteBytes: remoteBytes,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Phase 5: ConflictCopy
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeConflictCopy(
    ConflictCopy action, {
    List<int>? preloadedLocalBytes,
    List<int>? preloadedRemoteBytes,
  }) async {
    final stat = await fs.stat(action.path);
    if (stat == null) {
      _logger.fine(
        'Precondition mismatch: local file missing for conflict copy ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    final localBytes = preloadedLocalBytes ?? await fs.readBytes(action.path);
    final currentLocalHash = contentHash(localBytes);
    if (currentLocalHash != action.localHash) {
      _logger.fine(
        'Precondition mismatch: local hash $currentLocalHash != ${action.localHash} for conflict copy ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    // Check if an existing copy with localHash already exists in the folder
    VaultPath? existingCopyPath;
    final parentFolder = action.path.parent ?? VaultPath.root;
    final entries = await fs.list(folder: parentFolder, recursive: false);
    final prefix = '${action.path.stem} (conflict ';
    final ext = action.path.extension;

    for (final e in entries) {
      final name = e.path.name;
      final matchesExt = ext.isEmpty
          ? !name.contains('.')
          : name.endsWith('.$ext');
      if (name.startsWith(prefix) && matchesExt) {
        final bytes = await fs.readBytes(e.path);
        if (contentHash(bytes) == action.localHash) {
          existingCopyPath = e.path;
          break;
        }
      }
    }

    final VaultPath copyPath;
    if (existingCopyPath != null) {
      copyPath = existingCopyPath;
    } else {
      final now = clock.now().toUtc();
      final name = conflictCopyName(
        action.path,
        now,
        deviceName,
        (p) => entries.any((e) => e.path.value == p.value),
      );
      copyPath = VaultPath.raw(name);
      crashInjector?.call(CrashPoint.beforeLocalWrite, copyPath);
      await fs.writeBytes(copyPath, localBytes);
      crashInjector?.call(CrashPoint.afterLocalWrite, copyPath);
    }

    // Download remote content to target path
    final remoteBytes =
        preloadedRemoteBytes ??
        await blobStore.getFile(
          action.remote.blobKeys!,
          expectedPlainHash: action.remote.hash!,
        );

    final allowed = await editorGuard.mayReplace(action.path, action.localHash);
    if (!allowed) {
      return ExecutionResult(
        status: ExecutionStatus.skippedEditorGuard,
        action: action,
      );
    }

    if (localHistory != null) {
      await localHistory!.snapshot(
        action.path,
        localBytes,
        reason: SnapshotReason.beforeSyncOverwrite,
      );
    }

    crashInjector?.call(CrashPoint.beforeLocalWrite, action.path);
    await fs.writeBytes(action.path, remoteBytes);
    crashInjector?.call(CrashPoint.afterLocalWrite, action.path);

    await _updateBaseForEntry(action.path, action.remote);
    crashInjector?.call(CrashPoint.afterLocalStateUpdate, action.path);

    final staged = <Upload>[
      Upload(copyPath, localHash: action.localHash, parent: null),
    ];

    if (action.mergedParent != null) {
      staged.add(
        Upload(
          action.path,
          localHash: action.remote.hash!,
          parent: action.remote.id,
          mergedParent: action.mergedParent,
          reuseBlobKeys: action.remote.blobKeys,
        ),
      );
    }

    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;
    await store.addConflict(
      ConflictRecord(
        time: nowMs,
        path: action.path.value,
        copyPath: copyPath.value,
        kind: 'content',
        otherDevice: action.remote.deviceId,
      ),
    );

    await store.appendLog(
      SyncLogEntry(
        time: nowMs,
        level: 'warning',
        kind: 'conflictCopy',
        path: action.path.value,
        otherPath: copyPath.value,
        deviceName: action.remote.deviceId,
        detail: 'Conflict copy created: ${copyPath.value}',
      ),
    );

    return ExecutionResult(
      status: ExecutionStatus.applied,
      action: action,
      bytesDown: remoteBytes.length,
      stagedUploads: staged,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 6: Upload
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeUpload(Upload action) async {
    final stat = await fs.stat(action.path);
    if (stat == null) {
      _logger.fine(
        'Precondition mismatch: file missing for upload ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    final bytes = await fs.readBytes(action.path);
    final currentHash = contentHash(bytes);
    if (currentHash != action.localHash) {
      _logger.fine(
        'Precondition mismatch: local hash $currentHash != ${action.localHash} for upload ${action.path.value}',
      );
      return ExecutionResult(
        status: ExecutionStatus.skippedPrecondition,
        action: action,
      );
    }

    final List<String> blobKeys;
    if (action.reuseBlobKeys != null) {
      blobKeys = action.reuseBlobKeys!;
    } else {
      crashInjector?.call(CrashPoint.beforeBlobUpload, action.path);
      blobKeys = await blobStore.putFile(bytes, plainHash: action.localHash);
      crashInjector?.call(CrashPoint.afterBlobUpload, action.path);
    }

    await journalWriter.stage(
      op: 'put',
      path: action.path.value,
      hash: action.localHash,
      size: bytes.length,
      mtime: stat.modified.millisecondsSinceEpoch,
      blobKeys: blobKeys,
      parent: action.parent,
      mergedParent: action.mergedParent,
    );

    return ExecutionResult(
      status: ExecutionStatus.applied,
      action: action,
      bytesUp: action.reuseBlobKeys != null ? 0 : bytes.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 7: RenameRemote
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeRenameRemote(RenameRemote action) async {
    await journalWriter.stage(
      op: 'move',
      path: action.to.value,
      fromPath: action.path.value,
      hash: action.hash,
      blobKeys: action.blobKeys,
      parent: action.parent,
      targetParent: action.targetParent,
    );

    await store.appendLog(
      SyncLogEntry(
        time: clock.now().toUtc().millisecondsSinceEpoch,
        level: 'info',
        kind: 'renamedRemote',
        path: action.path.value,
        otherPath: action.to.value,
        deviceName: deviceName,
        detail: 'Staged remote move',
      ),
    );

    return ExecutionResult(status: ExecutionStatus.applied, action: action);
  }

  // ---------------------------------------------------------------------------
  // Phase 8: DeleteRemote
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _executeDeleteRemote(DeleteRemote action) async {
    await journalWriter.stage(
      op: 'delete',
      path: action.path.value,
      parent: action.parent,
    );

    await store.appendLog(
      SyncLogEntry(
        time: clock.now().toUtc().millisecondsSinceEpoch,
        level: 'info',
        kind: 'deletedRemote',
        path: action.path.value,
        deviceName: deviceName,
        detail: 'Staged remote deletion',
      ),
    );

    return ExecutionResult(status: ExecutionStatus.applied, action: action);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _updateBaseForEntry(VaultPath path, JournalEntry entry) async {
    final stat = await fs.stat(path);
    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;
    await store.putBase(
      BaseState(
        path: path.value,
        caseKey: path.caseKey,
        hash: entry.hash!,
        size: stat?.size ?? entry.size ?? 0,
        mtime: stat?.modified.millisecondsSinceEpoch ?? entry.mtime ?? 0,
        version: entry.id,
        blobKeys: entry.blobKeys ?? const [],
        syncedAt: nowMs,
      ),
    );
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[_random.nextInt(chars.length)]);
    }
    return sb.toString();
  }
}
