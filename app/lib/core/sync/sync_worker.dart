// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'secure_secret_store.dart';
import 'sync_messages.dart';

final _log = Logger('sync.worker');

/// Arguments passed to spawn the background sync worker isolate.
class SyncWorkerArgs {
  const SyncWorkerArgs({
    this.token,
    required this.vaultRootPath,
    required this.syncDatabasePath,
    required this.vaultId,
    required this.remoteVaultId,
    required this.deviceIdentity,
    required this.providerId,
    required this.mainSendPort,
    this.rootUrl,
  });

  final RootIsolateToken? token;
  final String vaultRootPath;
  final String syncDatabasePath;
  final String vaultId;
  final String remoteVaultId;
  final DeviceIdentity deviceIdentity;
  final String providerId;
  final SendPort mainSendPort;
  final String? rootUrl;
}

/// Entrypoint for the background sync worker isolate.
@pragma('vm:entry-point')
void syncWorkerMain(SyncWorkerArgs args) async {
  if (args.token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.token!);
  }

  final receivePort = ReceivePort();
  args.mainSendPort.send(receivePort.sendPort);

  final worker = SyncWorker(args, receivePort);
  await worker.init();
}

/// Implementation of the sync worker isolate state and dispatch loop.
class SyncWorker {
  SyncWorker(this.args, this.receivePort);

  final SyncWorkerArgs args;
  final ReceivePort receivePort;

  late final SendPort _mainPort = args.mainSendPort;
  final Map<int, Completer<dynamic>> _pendingMainRequests = {};

  VaultFileSystem? _fs;
  SyncStateStore? _store;
  SyncEngine? _engine;
  SyncProvider? _provider;
  bool _paused = false;

  SyncStatusSnapshot _snapshot = const SyncStatusSnapshot(
    state: SyncUiState.idle,
  );
  Timer? _backupScheduleTimer;

  void _send(WorkerMessage message) {
    _mainPort.send(message);
  }

  void _updateStatus(SyncStatusSnapshot newSnapshot) {
    _snapshot = newSnapshot;
    _send(StatusUpdate(newSnapshot));
  }

  Future<void> init() async {
    receivePort.listen(_handleMessage);

    try {
      // 1. Vault file system
      final fs = IoVaultFileSystem(args.vaultRootPath);
      _fs = fs;

      // 2. Sync database store
      _store = await SyncStateStore.open(args.syncDatabasePath);

      // 3. Object cipher
      ObjectCipher cipher = const PlaintextObjectCipher();
      try {
        final secretStore = SecureSecretStore();
        final masterKeyStr = await secretStore.read(
          SyncSecretKeys.masterKey(args.vaultId),
        );
        if (masterKeyStr != null && masterKeyStr.isNotEmpty) {
          final masterKeyBytes = base64Decode(masterKeyStr);
          if (masterKeyBytes.length == 32) {
            cipher = EncryptingObjectCipher(
              masterKey: MasterKey(masterKeyBytes).secretKey,
              vaultId: args.vaultId,
            );
          }
        }
      } catch (e) {
        _log.warning('Could not load master key; using plaintext: $e');
      }

      // 4. Token source bridging to main isolate
      final tokenSource = _WorkerTokenSource(_send, (id, comp) {
        _pendingMainRequests[id] = comp;
      });

      // 5. Remote sync provider
      if (args.providerId == 'memory') {
        _provider = MemorySyncProvider();
      } else {
        _provider = DriveSyncProvider(
          vaultId: args.remoteVaultId,
          vaultName: args.vaultId,
          tokenSource: tokenSource,
          rootUrl: args.rootUrl,
        );
      }

      // 6. Editor guard bridging to main isolate
      final editorGuard = _WorkerEditorGuard(_send, (id, comp) {
        _pendingMainRequests[id] = comp;
      });

      // 7. Engine
      _engine = SyncEngine(
        fs: fs,
        store: _store!,
        provider: _provider!,
        cipher: cipher,
        remoteVaultId: args.remoteVaultId,
        device: args.deviceIdentity,
        lock: FileSyncLock('${args.syncDatabasePath}.lock'),
        editorGuard: editorGuard,
      );

      _engine!.progress.listen((SyncProgress p) => _send(ProgressUpdate(p)));
      _engine!.log.listen((SyncLogEntry l) => _send(LogAppended(l)));

      _backupScheduleTimer?.cancel();
      _backupScheduleTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _checkAndRunScheduledBackup(),
      );
      unawaited(_checkAndRunScheduledBackup());

      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));
    } catch (e, st) {
      _log.severe('Failed to initialize sync worker: $e', e, st);
      _updateStatus(
        _snapshot.copyWith(
          state: SyncUiState.error,
          errorKind: e.runtimeType.toString(),
        ),
      );
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! SyncRequest) return;

    switch (message) {
      case final TokenReply reply:
        final comp = _pendingMainRequests.remove(reply.requestId);
        if (comp != null) {
          if (reply.token != null) {
            comp.complete(reply.token);
          } else {
            comp.completeError(
              AuthRevokedException(reply.errorType ?? 'Token unavailable'),
            );
          }
        }

      case final EditorGuardReply reply:
        final comp = _pendingMainRequests.remove(reply.requestId);
        comp?.complete(reply.canProceed);

      case final SyncNow req:
        _handleSyncNow(req);

      case final NotifyLocalChange req:
        _handleNotifyLocalChange(req);

      case final SetPaused req:
        _handleSetPaused(req);

      case final UpdateSettings req:
        _handleUpdateSettings(req);

      case final DecideHeldDeletes req:
        _handleDecideHeldDeletes(req);

      case final QueryLog req:
        _handleQueryLog(req);

      case final QueryConflicts req:
        _handleQueryConflicts(req);

      case final ResolveConflict req:
        _handleResolveConflict(req);

      case final QueryDevices req:
        _handleQueryDevices(req);

      case final RevokeDevice req:
        _handleRevokeDevice(req);

      case final QueryHistory req:
        _handleQueryHistory(req);

      case final LoadVersion req:
        _handleLoadVersion(req);

      case final RestoreVersion req:
        _handleRestoreVersion(req);

      case final QueryDeleted req:
        _handleQueryDeleted(req);

      case final RestoreDeleted req:
        _handleRestoreDeleted(req);

      case final ListBackups req:
        _handleListBackups(req);

      case final BackupNow req:
        _handleBackupNow(req);

      case final RestoreBackup req:
        _handleRestoreBackup(req);

      case final RunVerification req:
        _handleRunVerification(req);

      case final Shutdown req:
        _handleShutdown(req);
    }
  }

  Future<void> _handleSyncNow(SyncNow req) async {
    final engine = _engine;
    if (engine == null) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: 'NotInitialized',
          errorMessage: 'SyncEngine not ready',
        ),
      );
      return;
    }

    if (_paused) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: 'Paused',
          errorMessage: 'Sync is paused',
        ),
      );
      return;
    }

    final mode = await _store?.getMeta('mode');
    if (mode == 'backupOnly') {
      await _checkAndRunScheduledBackup();
      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));
      _send(
        WorkerReply(
          requestId: req.requestId,
          payload: const SyncReport(duration: Duration.zero),
        ),
      );
      return;
    }

    _updateStatus(_snapshot.copyWith(state: SyncUiState.syncing));

    try {
      final report = await engine.syncOnce(trigger: req.trigger);
      await _checkAndRunScheduledBackup();

      final conflicts = await _store?.conflicts(unresolvedOnly: true) ?? [];
      final heldJson = await _store?.getMeta('heldDeletes');
      final heldList = heldJson != null
          ? (jsonDecode(heldJson) as List).cast<String>()
          : <String>[];

      SyncUiState nextState = SyncUiState.idle;
      if (conflicts.isNotEmpty || heldList.isNotEmpty) {
        nextState = SyncUiState.needsAttention;
      }

      Quota? q;
      try {
        q = await _provider?.quota();
      } catch (_) {}

      _updateStatus(
        _snapshot.copyWith(
          state: nextState,
          lastSyncAt: DateTime.now().toUtc(),
          unresolvedConflicts: conflicts.length,
          heldDeletes: heldList.map(VaultPath.new).toList(),
          quota: q ?? _snapshot.quota,
          errorKind: null,
        ),
      );

      _send(WorkerReply(requestId: req.requestId, payload: report));
    } catch (e, st) {
      _log.warning('Sync cycle failed: $e', e, st);

      SyncUiState errorState = SyncUiState.error;
      if (e is NetworkUnavailableException ||
          e is RateLimitedException ||
          e is RemoteServerException ||
          e is SocketException) {
        errorState = SyncUiState.offline;
      } else if (e is AuthRevokedException || e is DeviceRevokedException) {
        errorState = SyncUiState.needsAttention;
      }

      _updateStatus(
        _snapshot.copyWith(
          state: errorState,
          errorKind: e.runtimeType.toString(),
        ),
      );

      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: e.runtimeType.toString(),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _handleNotifyLocalChange(NotifyLocalChange req) {
    final newCount = _snapshot.pendingLocalChanges + req.paths.length;
    _updateStatus(_snapshot.copyWith(pendingLocalChanges: newCount));
    _send(WorkerReply(requestId: req.requestId, payload: true));
  }

  void _handleSetPaused(SetPaused req) {
    _paused = req.paused;
    _updateStatus(
      _snapshot.copyWith(
        state: _paused ? SyncUiState.paused : SyncUiState.idle,
      ),
    );
    _send(WorkerReply(requestId: req.requestId, payload: true));
  }

  void _handleUpdateSettings(UpdateSettings req) {
    _send(WorkerReply(requestId: req.requestId, payload: true));
  }

  Future<void> _handleDecideHeldDeletes(DecideHeldDeletes req) async {
    _send(WorkerReply(requestId: req.requestId, payload: true));
  }

  Future<void> _handleQueryLog(QueryLog req) async {
    try {
      final log = await _store?.log(limit: req.limit) ?? [];
      _send(WorkerReply(requestId: req.requestId, payload: log));
    } catch (e) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: e.runtimeType.toString(),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleQueryConflicts(QueryConflicts req) async {
    try {
      final list = await _store?.conflicts(unresolvedOnly: true) ?? [];
      _send(WorkerReply(requestId: req.requestId, payload: list));
    } catch (e) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: e.runtimeType.toString(),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleResolveConflict(ResolveConflict req) async {
    try {
      if (_engine != null) {
        await _engine!.conflictResolver.resolve(
          conflictId: req.conflictId,
          resolution: req.resolution,
          mergedText: req.mergedText,
        );
      } else if (_store != null && _fs != null) {
        final resolver = ConflictResolver(
          fs: _fs!,
          store: _store!,
          localHistory: LocalHistory(_fs!),
        );
        await resolver.resolve(
          conflictId: req.conflictId,
          resolution: req.resolution,
          mergedText: req.mergedText,
        );
      }
      final remaining = await _store?.conflicts(unresolvedOnly: true) ?? [];
      _updateStatus(
        _snapshot.copyWith(
          unresolvedConflicts: remaining.length,
          state: (remaining.isEmpty && _snapshot.heldDeletes.isEmpty)
              ? SyncUiState.idle
              : _snapshot.state,
        ),
      );
      _send(WorkerReply(requestId: req.requestId, payload: true));
    } catch (e) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: e.runtimeType.toString(),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleQueryDevices(QueryDevices req) async {
    try {
      final cursors = await _store?.allCursors() ?? [];
      final list = cursors
          .map(
            (c) => RemoteDevice(
              deviceId: c.deviceId,
              deviceName: c.deviceName ?? 'Device',
              platform: 'unknown',
              registeredAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ),
          )
          .toList();
      _send(WorkerReply(requestId: req.requestId, payload: list));
    } catch (e) {
      _send(
        WorkerReply(
          requestId: req.requestId,
          errorType: e.runtimeType.toString(),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleRevokeDevice(RevokeDevice req) async {
    _send(WorkerReply(requestId: req.requestId, payload: true));
  }

  Future<VersionHistory> _createVersionHistory() async {
    final remoteHistory =
        await _engine?.getRemoteHistory() ?? RemoteHistory(const []);
    final deviceNames = <String, String>{};
    if (_store != null) {
      final cursors = await _store!.allCursors();
      for (final c in cursors) {
        if (c.deviceName != null && c.deviceName!.isNotEmpty) {
          deviceNames[c.deviceId] = c.deviceName!;
        }
      }
    }
    return VersionHistory(
      localHistory: _engine?.historyManager ?? LocalHistory(_fs!),
      remoteHistory: remoteHistory,
      blobStore: _engine?.blobStore,
      deviceNames: deviceNames,
    );
  }

  Future<void> _handleQueryHistory(QueryHistory req) async {
    try {
      final vh = await _createVersionHistory();
      final versions = await vh.versions(VaultPath(req.path));
      _send(WorkerReply(requestId: req.requestId, payload: versions));
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleLoadVersion(LoadVersion req) async {
    try {
      final vh = await _createVersionHistory();
      List<int>? bytes;
      final ref = req.versionRef;
      if (ref is VersionInfo) {
        bytes = await vh.readVersion(ref);
      } else if (ref is VersionRef) {
        if (ref is LocalVersionRef) {
          bytes = await vh.localHistory.read(ref.path);
        } else if (ref is RemoteVersionRef && vh.blobStore != null) {
          bytes = await vh.blobStore!.getFile(
            ref.blobKeys,
            expectedPlainHash: ref.hash ?? '',
          );
        }
      } else if (ref is String) {
        if (ref.endsWith('.gz') || ref.startsWith('.tephra/history/')) {
          bytes = await vh.localHistory.read(ref);
        } else {
          final entry = vh.remoteHistory.byId[ref];
          if (entry != null && vh.blobStore != null && entry.blobKeys != null) {
            bytes = await vh.blobStore!.getFile(
              entry.blobKeys!,
              expectedPlainHash: entry.hash ?? '',
            );
          }
        }
      }
      _send(WorkerReply(requestId: req.requestId, payload: bytes));
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleRestoreVersion(RestoreVersion req) async {
    try {
      final vh = await _createVersionHistory();
      List<int>? bytes;
      final ref = req.versionRef;
      if (ref is VersionInfo) {
        bytes = await vh.readVersion(ref);
      } else if (ref is VersionRef) {
        if (ref is LocalVersionRef) {
          bytes = await vh.localHistory.read(ref.path);
        } else if (ref is RemoteVersionRef && vh.blobStore != null) {
          bytes = await vh.blobStore!.getFile(
            ref.blobKeys,
            expectedPlainHash: ref.hash ?? '',
          );
        }
      } else if (ref is String) {
        if (ref.endsWith('.gz') || ref.startsWith('.tephra/history/')) {
          bytes = await vh.localHistory.read(ref);
        } else {
          final entry = vh.remoteHistory.byId[ref];
          if (entry != null && vh.blobStore != null && entry.blobKeys != null) {
            bytes = await vh.blobStore!.getFile(
              entry.blobKeys!,
              expectedPlainHash: entry.hash ?? '',
            );
          }
        }
      }

      if (bytes == null) {
        _send(
          WorkerReply(
            requestId: req.requestId,
            errorType: 'Version content unavailable',
          ),
        );
        return;
      }

      final targetPath = VaultPath(req.path);
      final currentStat = await _fs!.stat(targetPath);
      if (currentStat != null) {
        final currentBytes = await _fs!.readBytes(targetPath);
        await vh.localHistory.snapshot(
          targetPath,
          currentBytes,
          reason: SnapshotReason.beforeRestore,
        );
      }

      await _fs!.writeBytes(targetPath, bytes);
      _send(WorkerReply(requestId: req.requestId, payload: true));
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleQueryDeleted(QueryDeleted req) async {
    try {
      final vh = await _createVersionHistory();
      final deleted = await vh.recentlyDeleted(fs: _fs!);
      _send(WorkerReply(requestId: req.requestId, payload: deleted));
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleRestoreDeleted(RestoreDeleted req) async {
    try {
      final vh = await _createVersionHistory();
      final targetPath = await vh.restoreDeletedFile(
        deleted: req.deleted,
        fs: _fs!,
      );
      _send(WorkerReply(requestId: req.requestId, payload: targetPath.value));
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  BackupService? _createBackupService() {
    final engine = _engine;
    if (engine == null || _store == null || _provider == null || _fs == null) {
      return null;
    }
    return BackupService(
      vaultId: engine.remoteVaultId,
      deviceId: engine.device.deviceId,
      deviceName: engine.device.deviceName,
      fs: _fs!,
      blobStore: engine.blobStore,
      provider: _provider!,
      cipher: engine.cipher,
      store: _store!,
      syncLock: engine.lock,
      clock: engine.clock,
    );
  }

  Future<void> _checkAndRunScheduledBackup() async {
    try {
      final scheduleStr = await _store?.getMeta('backupSchedule');
      final schedule = BackupScheduleFrequency.fromString(scheduleStr);
      if (schedule == BackupScheduleFrequency.off) return;

      final lastBackupStr = await _store?.getMeta('lastBackupAt');
      final lastBackupAt = lastBackupStr != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.parse(lastBackupStr),
              isUtc: true,
            )
          : null;

      final now = DateTime.now().toUtc();
      if (BackupSchedule.isDue(now, lastBackupAt, schedule)) {
        final backupService = _createBackupService();
        if (backupService != null) {
          await backupService.runBackup(kind: BackupKind.scheduled);
        }
      }
    } catch (e) {
      _log.warning('Scheduled backup check failed: $e');
    }
  }

  Future<void> _handleListBackups(ListBackups req) async {
    try {
      final service = _createBackupService();
      if (service == null) {
        _send(WorkerReply(requestId: req.requestId, payload: const []));
        return;
      }
      final manifests = await service.listBackups();
      _send(
        WorkerReply(
          requestId: req.requestId,
          payload: manifests.map((m) => m.toJson()).toList(),
        ),
      );
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleBackupNow(BackupNow req) async {
    try {
      final service = _createBackupService();
      if (service == null) {
        _send(
          WorkerReply(
            requestId: req.requestId,
            errorType: 'Sync engine not ready',
          ),
        );
        return;
      }
      _updateStatus(_snapshot.copyWith(state: SyncUiState.syncing));
      await service.runBackup(kind: req.kind);
      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));
      _send(WorkerReply(requestId: req.requestId, payload: true));
    } catch (e) {
      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  RestoreService? _createRestoreService() {
    final engine = _engine;
    if (engine == null || _provider == null || _fs == null) {
      return null;
    }
    return RestoreService(
      provider: _provider!,
      cipher: engine.cipher,
      blobStore: engine.blobStore,
      fs: _fs!,
      backupService: _createBackupService(),
      clock: engine.clock,
    );
  }

  BackupVerifier? _createBackupVerifier() {
    final engine = _engine;
    if (engine == null || _provider == null || _store == null) {
      return null;
    }
    return BackupVerifier(
      provider: _provider!,
      cipher: engine.cipher,
      store: _store!,
      clock: engine.clock,
    );
  }

  Future<void> _handleRestoreBackup(RestoreBackup req) async {
    try {
      final service = _createRestoreService();
      if (service == null) {
        _send(
          WorkerReply(
            requestId: req.requestId,
            errorType: 'Sync engine not ready',
          ),
        );
        return;
      }
      final map = req.request;
      final stamp = map['stamp'] as String;
      final selection = ((map['selection'] as List?) ?? const [])
          .map((p) => VaultPath(p as String))
          .toList();
      final targetMode = map['targetMode'] as String? ?? 'intoVault';
      final RestoreTarget target;
      if (targetMode == 'newFolder') {
        target = RestoreTarget.newFolder(map['targetPath'] as String);
      } else {
        target = RestoreTarget.intoVault;
      }

      final request = RestoreRequest(
        stamp: stamp,
        selection: selection,
        target: target,
      );

      _updateStatus(_snapshot.copyWith(state: SyncUiState.syncing));
      final report = await service.restore(request);
      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));

      _send(
        WorkerReply(
          requestId: req.requestId,
          payload: {
            'restored': report.restoredCount,
            'skipped': report.skippedCount,
            'renamed': report.renamedCount,
            'failed': report.failedCount,
            'failedPaths': report.failedPaths,
          },
        ),
      );
    } catch (e) {
      _updateStatus(_snapshot.copyWith(state: SyncUiState.idle));
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleRunVerification(RunVerification req) async {
    try {
      final verifier = _createBackupVerifier();
      if (verifier == null) {
        _send(
          WorkerReply(
            requestId: req.requestId,
            errorType: 'Sync engine not ready',
          ),
        );
        return;
      }
      final record = await verifier.verify();
      _send(
        WorkerReply(
          requestId: req.requestId,
          payload: {
            'stamp': record.stamp,
            'sampled': record.sampled,
            'ok': record.ok,
            'failed': record.failed,
            'failedKeys': record.failedKeys,
          },
        ),
      );
    } catch (e) {
      _send(WorkerReply(requestId: req.requestId, errorType: e.toString()));
    }
  }

  Future<void> _handleShutdown(Shutdown req) async {
    _backupScheduleTimer?.cancel();
    _backupScheduleTimer = null;
    _send(WorkerReply(requestId: req.requestId, payload: true));
    await _store?.close();
    await _provider?.quota(); // no-op safe
    receivePort.close();
  }
}

class _WorkerTokenSource implements AccessTokenSource {
  _WorkerTokenSource(this._sendToMain, this._registerPending);

  final void Function(WorkerMessage) _sendToMain;
  final void Function(int requestId, Completer<String> completer)
  _registerPending;

  String? _cachedToken;
  DateTime? _expiresAt;
  int _nextRequestId = 1000000;

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    final now = DateTime.now().toUtc();
    if (!forceRefresh &&
        _cachedToken != null &&
        _expiresAt != null &&
        _expiresAt!.difference(now) > const Duration(minutes: 2)) {
      return _cachedToken!;
    }

    final reqId = _nextRequestId++;
    final completer = Completer<String>();
    _registerPending(reqId, completer);

    _sendToMain(TokenRequest(requestId: reqId, forceRefresh: forceRefresh));
    final token = await completer.future;
    _cachedToken = token;
    _expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 58));
    return token;
  }

  @override
  Future<void> signOut() async {
    _cachedToken = null;
    _expiresAt = null;
  }
}

class _WorkerEditorGuard implements EditorGuard {
  _WorkerEditorGuard(this._sendToMain, this._registerPending);

  final void Function(WorkerMessage) _sendToMain;
  final void Function(int requestId, Completer<bool> completer)
  _registerPending;
  int _nextRequestId = 2000000;

  @override
  Future<bool> mayReplace(VaultPath path, String expectedHash) {
    final reqId = _nextRequestId++;
    final completer = Completer<bool>();
    _registerPending(reqId, completer);

    _sendToMain(
      EditorGuardRequest(
        requestId: reqId,
        path: path.value,
        expectedHash: expectedHash,
      ),
    );

    return completer.future;
  }
}
