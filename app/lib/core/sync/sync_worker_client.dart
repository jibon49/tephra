// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import 'editor_guard_host.dart';
import 'sync_messages.dart';

/// Client residing on the main UI isolate to communicate with the background [SyncWorker].
class SyncWorkerClient {
  SyncWorkerClient({
    required this._workerSendPort,
    ReceivePort? receivePort,
    this.tokenHandler,
    this.editorGuardHost,
  }) : _receivePort = receivePort ?? ReceivePort() {
    _receivePort.listen(_handleWorkerMessage);
  }

  final SendPort _workerSendPort;
  final ReceivePort _receivePort;
  final Future<String> Function(bool forceRefresh)? tokenHandler;
  final EditorGuardHost? editorGuardHost;

  int _nextRequestId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};

  final StreamController<SyncStatusSnapshot> _statusController =
      StreamController<SyncStatusSnapshot>.broadcast();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  final StreamController<SyncLogEntry> _logController =
      StreamController<SyncLogEntry>.broadcast();

  SyncStatusSnapshot _lastStatus = const SyncStatusSnapshot(
    state: SyncUiState.idle,
  );

  SyncStatusSnapshot get currentStatus => _lastStatus;
  Stream<SyncStatusSnapshot> get statusStream => _statusController.stream;
  Stream<SyncProgress> get progressStream => _progressController.stream;
  Stream<SyncLogEntry> get logStream => _logController.stream;

  SendPort get mainSendPort => _receivePort.sendPort;

  void _handleWorkerMessage(dynamic message) async {
    if (message is! WorkerMessage) return;

    switch (message) {
      case final StatusUpdate update:
        _lastStatus = update.snapshot;
        if (!_statusController.isClosed) {
          _statusController.add(update.snapshot);
        }

      case final ProgressUpdate update:
        if (!_progressController.isClosed) {
          _progressController.add(update.progress);
        }

      case final LogAppended update:
        if (!_logController.isClosed) {
          _logController.add(update.entry);
        }

      case final TokenRequest req:
        unawaited(_handleTokenRequest(req));

      case final EditorGuardRequest req:
        unawaited(_handleEditorGuardRequest(req));

      case final WorkerReply reply:
        final comp = _pendingRequests.remove(reply.requestId);
        if (comp != null) {
          if (reply.isSuccess) {
            comp.complete(reply.payload);
          } else {
            comp.completeError(
              SyncException(
                reply.errorMessage ?? 'Worker error: ${reply.errorType}',
              ),
            );
          }
        }
    }
  }

  Future<void> _handleTokenRequest(TokenRequest req) async {
    try {
      final token =
          await (tokenHandler?.call(req.forceRefresh) ??
              Future.value('stub_token'));
      _workerSendPort.send(TokenReply(req.requestId, token: token));
    } catch (e) {
      _workerSendPort.send(
        TokenReply(req.requestId, errorType: e.runtimeType.toString()),
      );
    }
  }

  Future<void> _handleEditorGuardRequest(EditorGuardRequest req) async {
    bool canProceed = true;
    if (editorGuardHost != null) {
      canProceed = await editorGuardHost!.handleRequest(
        req.path,
        req.expectedHash,
      );
    }
    _workerSendPort.send(EditorGuardReply(req.requestId, canProceed));
  }

  Future<T> _sendRequest<T>(SyncRequest Function(int requestId) builder) {
    final reqId = _nextRequestId++;
    final comp = Completer<T>();
    _pendingRequests[reqId] = comp;

    final request = builder(reqId);
    _workerSendPort.send(request);
    return comp.future;
  }

  /// Triggers a sync cycle.
  Future<SyncReport?> syncNow({SyncTrigger trigger = SyncTrigger.manual}) {
    return _sendRequest<SyncReport?>((id) => SyncNow(id, trigger: trigger));
  }

  /// Informs the worker of local file saves.
  Future<void> notifyLocalChange(List<VaultPath> paths) {
    return _sendRequest<bool>((id) => NotifyLocalChange(id, paths));
  }

  /// Pauses or resumes sync operations.
  Future<void> setPaused(bool paused) {
    return _sendRequest<bool>((id) => SetPaused(id, paused));
  }

  /// Queries the most recent sync log entries.
  Future<List<SyncLogEntry>> queryLog({int limit = 100}) async {
    final res = await _sendRequest<List<dynamic>>(
      (id) => QueryLog(id, limit: limit),
    );
    return res.cast<SyncLogEntry>();
  }

  /// Queries currently unresolved conflict records.
  Future<List<ConflictRecord>> queryConflicts() async {
    final res = await _sendRequest<List<dynamic>>((id) => QueryConflicts(id));
    return res.cast<ConflictRecord>();
  }

  /// Resolves a conflict record.
  Future<void> resolveConflict(
    int conflictId,
    ConflictResolution resolution, {
    String? mergedText,
  }) {
    return _sendRequest<bool>(
      (id) =>
          ResolveConflict(id, conflictId, resolution, mergedText: mergedText),
    );
  }

  /// Queries known paired remote devices.
  Future<List<RemoteDevice>> queryDevices() async {
    final res = await _sendRequest<List<dynamic>>((id) => QueryDevices(id));
    return res.cast<RemoteDevice>();
  }

  /// Submits user decisions for held deletions.
  Future<void> decideHeldDeletes(Map<String, DeleteDecision> decisions) {
    return _sendRequest<bool>((id) => DecideHeldDeletes(id, decisions));
  }

  /// Updates runtime sync settings.
  Future<void> updateSettings(SyncWorkerSettings settings) {
    return _sendRequest<bool>((id) => UpdateSettings(id, settings));
  }

  /// Revokes a remote device.
  Future<void> revokeDevice(String deviceId) {
    return _sendRequest<bool>((id) => RevokeDevice(id, deviceId));
  }

  /// Queries all historical versions for [path].
  Future<List<VersionInfo>> queryHistory(VaultPath path) async {
    final res = await _sendRequest<List<dynamic>>(
      (id) => QueryHistory(id, path.value),
    );
    return res.cast<VersionInfo>();
  }

  /// Loads the uncompressed bytes for [versionRef].
  Future<List<int>?> loadVersion(dynamic versionRef) {
    return _sendRequest<List<int>?>((id) => LoadVersion(id, versionRef));
  }

  /// Restores [versionRef] to [path], snapshotting current content first.
  Future<bool> restoreVersion(dynamic versionRef, VaultPath path) {
    return _sendRequest<bool>(
      (id) => RestoreVersion(id, versionRef, path.value),
    );
  }

  /// Queries recently deleted files available for restore.
  Future<List<RecentlyDeletedFile>> queryDeleted() async {
    final res = await _sendRequest<List<dynamic>>((id) => QueryDeleted(id));
    return res.cast<RecentlyDeletedFile>();
  }

  /// Restores a recently deleted file to its path (or collision name).
  Future<String> restoreDeleted(RecentlyDeletedFile deleted) {
    return _sendRequest<String>((id) => RestoreDeleted(id, deleted));
  }

  /// Lists all accessible backup manifests sorted newest first.
  Future<List<BackupManifest>> listBackups() async {
    final res = await _sendRequest<List<dynamic>>((id) => ListBackups(id));
    return res.map((m) {
      if (m is BackupManifest) return m;
      return BackupManifest.fromJson(m as Map<String, dynamic>);
    }).toList();
  }

  /// Triggers an immediate point-in-time vault backup.
  Future<bool> backupNow({BackupKind kind = BackupKind.manual}) {
    return _sendRequest<bool>((id) => BackupNow(id, kind: kind));
  }

  /// Executes a backup restore operation with [request].
  Future<Map<String, dynamic>> restoreBackup(
    Map<String, dynamic> request,
  ) async {
    final res = await _sendRequest<dynamic>((id) => RestoreBackup(id, request));
    return (res as Map).cast<String, dynamic>();
  }

  /// Runs backup verification on the newest backup manifest.
  Future<Map<String, dynamic>> runVerification() async {
    final res = await _sendRequest<dynamic>((id) => RunVerification(id));
    return (res as Map).cast<String, dynamic>();
  }

  /// Shuts down the sync worker and releases isolate ports.
  Future<void> shutdown() async {
    try {
      await _sendRequest<bool>((id) => Shutdown(id))
          .timeout(const Duration(seconds: 3), onTimeout: () => true);
    } catch (_) {}

    _receivePort.close();
    await _statusController.close();
    await _progressController.close();
    await _logController.close();
    _pendingRequests.clear();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provider for the [SyncWorkerClient] active for a given vault.
final syncWorkerClientProvider = Provider.family<SyncWorkerClient?, String>((
  ref,
  vaultId,
) {
  // If sync is not configured for this vault, returns null
  return null;
});

/// Stream of status snapshots for a given vault.
final syncStatusProvider = StreamProvider.family<SyncStatusSnapshot, String>((
  ref,
  vaultId,
) {
  final client = ref.watch(syncWorkerClientProvider(vaultId));
  if (client == null) {
    return Stream.value(
      const SyncStatusSnapshot(state: SyncUiState.notConfigured),
    );
  }
  return client.statusStream;
});

/// Stream of sync progress updates for a given vault.
final syncProgressProvider = StreamProvider.family<SyncProgress, String>((
  ref,
  vaultId,
) {
  final client = ref.watch(syncWorkerClientProvider(vaultId));
  if (client == null) {
    return const Stream.empty();
  }
  return client.progressStream;
});

/// Stream of log entries for a given vault.
final syncLogProvider = StreamProvider.family<SyncLogEntry, String>((
  ref,
  vaultId,
) {
  final client = ref.watch(syncWorkerClientProvider(vaultId));
  if (client == null) {
    return const Stream.empty();
  }
  return client.logStream;
});
