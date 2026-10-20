// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

/// User-facing state of the synchronization subsystem.
enum SyncUiState {
  notConfigured,
  idle,
  syncing,
  pending,
  offline,
  paused,
  needsAttention,
  error,
}

/// Snapshot of sync state for UI observation and status bars.
class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.state,
    this.pendingLocalChanges = 0,
    this.unresolvedConflicts = 0,
    this.heldDeletes = const [],
    this.lastSyncAt,
    this.errorKind,
    this.quota,
    this.accountEmail,
  });

  final SyncUiState state;
  final int pendingLocalChanges;
  final int unresolvedConflicts;
  final List<VaultPath> heldDeletes;
  final DateTime? lastSyncAt;
  final String? errorKind;
  final Quota? quota;
  final String? accountEmail;

  SyncStatusSnapshot copyWith({
    SyncUiState? state,
    int? pendingLocalChanges,
    int? unresolvedConflicts,
    List<VaultPath>? heldDeletes,
    DateTime? lastSyncAt,
    String? errorKind,
    Quota? quota,
    String? accountEmail,
  }) {
    return SyncStatusSnapshot(
      state: state ?? this.state,
      pendingLocalChanges: pendingLocalChanges ?? this.pendingLocalChanges,
      unresolvedConflicts: unresolvedConflicts ?? this.unresolvedConflicts,
      heldDeletes: heldDeletes ?? this.heldDeletes,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      errorKind: errorKind ?? this.errorKind,
      quota: quota ?? this.quota,
      accountEmail: accountEmail ?? this.accountEmail,
    );
  }
}

/// Settings passed to the sync worker.
class SyncWorkerSettings {
  const SyncWorkerSettings({
    this.syncMode = SyncMode.live,
    this.upKiBps = 0,
    this.downKiBps = 0,
    this.paused = false,
  });

  final SyncMode syncMode;
  final int upKiBps;
  final int downKiBps;
  final bool paused;
}

// ---------------------------------------------------------------------------
// Main -> Worker Messages
// ---------------------------------------------------------------------------

/// Base sealed class for requests sent from main isolate to sync worker.
sealed class SyncRequest {
  const SyncRequest(this.requestId);
  final int requestId;
}

final class SyncNow extends SyncRequest {
  const SyncNow(super.requestId, {this.trigger = SyncTrigger.manual});
  final SyncTrigger trigger;
}

final class NotifyLocalChange extends SyncRequest {
  const NotifyLocalChange(super.requestId, this.paths);
  final List<VaultPath> paths;
}

final class SetPaused extends SyncRequest {
  const SetPaused(super.requestId, this.paused);
  final bool paused;
}

final class UpdateSettings extends SyncRequest {
  const UpdateSettings(super.requestId, this.settings);
  final SyncWorkerSettings settings;
}

final class DecideHeldDeletes extends SyncRequest {
  const DecideHeldDeletes(super.requestId, this.decisions);
  final Map<String, DeleteDecision> decisions;
}

final class QueryLog extends SyncRequest {
  const QueryLog(super.requestId, {this.limit = 100});
  final int limit;
}

final class QueryConflicts extends SyncRequest {
  const QueryConflicts(super.requestId);
}

final class ResolveConflict extends SyncRequest {
  const ResolveConflict(
    super.requestId,
    this.conflictId,
    this.resolution, {
    this.mergedText,
  });
  final int conflictId;
  final ConflictResolution resolution;
  final String? mergedText;
}

final class QueryDevices extends SyncRequest {
  const QueryDevices(super.requestId);
}

final class RevokeDevice extends SyncRequest {
  const RevokeDevice(super.requestId, this.deviceId);
  final String deviceId;
}

final class QueryHistory extends SyncRequest {
  const QueryHistory(super.requestId, this.path);
  final String path;
}

final class LoadVersion extends SyncRequest {
  const LoadVersion(super.requestId, this.versionRef);
  final dynamic versionRef;
}

final class RestoreVersion extends SyncRequest {
  const RestoreVersion(super.requestId, this.versionRef, this.path);
  final dynamic versionRef;
  final String path;
}

final class QueryDeleted extends SyncRequest {
  const QueryDeleted(super.requestId);
}

final class RestoreDeleted extends SyncRequest {
  const RestoreDeleted(super.requestId, this.deleted);
  final RecentlyDeletedFile deleted;
}

final class ListBackups extends SyncRequest {
  const ListBackups(super.requestId);
}

final class BackupNow extends SyncRequest {
  const BackupNow(super.requestId);
}

final class RestoreBackup extends SyncRequest {
  const RestoreBackup(super.requestId, this.request);
  final Map<String, dynamic> request;
}

final class RunVerification extends SyncRequest {
  const RunVerification(super.requestId);
}

final class TokenReply extends SyncRequest {
  const TokenReply(super.requestId, {this.token, this.errorType});
  final String? token;
  final String? errorType;
}

final class EditorGuardReply extends SyncRequest {
  const EditorGuardReply(super.requestId, this.canProceed);
  final bool canProceed;
}

final class Shutdown extends SyncRequest {
  const Shutdown(super.requestId);
}

// ---------------------------------------------------------------------------
// Worker -> Main Messages
// ---------------------------------------------------------------------------

/// Base sealed class for messages sent from sync worker to main isolate.
sealed class WorkerMessage {
  const WorkerMessage();
}

final class StatusUpdate extends WorkerMessage {
  const StatusUpdate(this.snapshot);
  final SyncStatusSnapshot snapshot;
}

final class ProgressUpdate extends WorkerMessage {
  const ProgressUpdate(this.progress);
  final SyncProgress progress;
}

final class LogAppended extends WorkerMessage {
  const LogAppended(this.entry);
  final SyncLogEntry entry;
}

final class TokenRequest extends WorkerMessage {
  const TokenRequest({required this.requestId, this.forceRefresh = false});
  final int requestId;
  final bool forceRefresh;
}

final class EditorGuardRequest extends WorkerMessage {
  const EditorGuardRequest({
    required this.requestId,
    required this.path,
    required this.expectedHash,
  });
  final int requestId;
  final String path;
  final String expectedHash;
}

final class WorkerReply extends WorkerMessage {
  const WorkerReply({
    required this.requestId,
    this.payload,
    this.errorType,
    this.errorMessage,
  });
  final int requestId;
  final Object? payload;
  final String? errorType;
  final String? errorMessage;

  bool get isSuccess => errorType == null;
}
