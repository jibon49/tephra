// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../blobs/blob_store.dart';
import '../crypto/object_cipher.dart';
import '../errors/sync_exceptions.dart';
import '../executor/crash_injector.dart';
import '../executor/editor_guard.dart';
import '../executor/executor.dart';
import '../history/local_history.dart';
import '../local/case_sensitivity.dart';
import '../local/local_scanner.dart';
import '../model/base_state.dart';
import '../model/device_identity.dart';
import '../model/hlc.dart';
import '../model/journal_batch.dart';
import '../model/selective_sync_rules.dart';
import '../model/sync_log_entry.dart';
import '../planner/base_update.dart';
import '../planner/delete_decision.dart';
import '../planner/planner.dart';
import '../planner/planner_input.dart';
import '../planner/sync_action.dart';
import '../provider/sync_provider.dart';
import '../remote/device_registry.dart';
import '../remote/journal_reader.dart';
import '../remote/journal_writer.dart';
import '../remote/remote_history.dart';
import '../remote/snapshot_store.dart';
import '../store/sync_state_store.dart';
import 'sync_cancel_token.dart';
import 'sync_lock.dart';
import 'sync_progress.dart';
import 'sync_report.dart';
import 'sync_trigger.dart';

final _logger = Logger('SyncEngine');

/// Main synchronization engine orchestrating crash-safe, idempotent, resumable sync cycles.
final class SyncEngine {
  /// Creates a [SyncEngine] with all dependencies injected.
  SyncEngine({
    required this.fs,
    required this.provider,
    required this.store,
    required this.cipher,
    required this.remoteVaultId,
    required this.device,
    required this.lock,
    this.clock = const SystemClock(),
    Random? random,
    this.crashInjector,
    this.editorGuard = const AllowAllEditorGuard(),
    this.localHistory,
  }) : _random = random ?? Random() {
    _hlcClock = HlcClock(
      deviceId: device.deviceId,
      clock: clock,
      onPersist: (millis, counter) async {
        await store.setMeta('hlc_millis', millis.toString());
        await store.setMeta('hlc_counter', counter.toString());
      },
    );

    _blobStore = BlobStore(
      provider: provider,
      cipher: cipher,
      store: store,
      clock: clock,
    );

    _journalWriter = JournalWriter(
      provider: provider,
      cipher: cipher,
      store: store,
      hlcClock: _hlcClock,
      clock: clock,
      crashInjector: crashInjector,
    );

    _journalReader = JournalReader(
      provider: provider,
      cipher: cipher,
      store: store,
      hlcClock: _hlcClock,
      clock: clock,
    );

    _snapshotStore = SnapshotStore(
      provider: provider,
      cipher: cipher,
      store: store,
      hlcClock: _hlcClock,
      clock: clock,
    );

    _deviceRegistry = DeviceRegistry(provider, cipher, clock: clock);

    _executor = Executor(
      fs: fs,
      store: store,
      blobStore: _blobStore,
      journalWriter: _journalWriter,
      deviceName: device.deviceName,
      editorGuard: editorGuard,
      localHistory: localHistory,
      crashInjector: crashInjector,
      clock: clock,
      random: _random,
    );
  }

  final VaultFileSystem fs;
  final SyncProvider provider;
  final SyncStateStore store;
  final ObjectCipher cipher;
  final String remoteVaultId;
  final DeviceIdentity device;
  final SyncLock lock;
  final Clock clock;
  final Random _random;
  final CrashInjector? crashInjector;
  final EditorGuard editorGuard;
  final LocalHistory? localHistory;

  late final HlcClock _hlcClock;
  late final BlobStore _blobStore;
  late final JournalWriter _journalWriter;
  late final JournalReader _journalReader;
  late final SnapshotStore _snapshotStore;
  late final DeviceRegistry _deviceRegistry;
  late final Executor _executor;

  final _progressController = StreamController<SyncProgress>.broadcast();
  final _logController = StreamController<SyncLogEntry>.broadcast();
  DateTime? _lastProgressEmit;

  /// Stream of cycle progress updates.
  Stream<SyncProgress> get progress => _progressController.stream;

  /// Stream of user-visible log entries emitted during synchronization.
  Stream<SyncLogEntry> get log => _logController.stream;

  /// Executes a single, full synchronization cycle.
  Future<SyncReport> syncOnce({
    SyncTrigger trigger = SyncTrigger.manual,
    SyncCancelToken? cancel,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Acquire lock
    final acquired = await lock.tryAcquire();
    if (!acquired) {
      throw const SyncLockedException();
    }

    try {
      crashInjector?.call(CrashPoint.cycleStart, null);

      // 2. Recover uncommitted pending journal batches
      _emitProgress(SyncProgressPhase.refreshing);
      await _journalWriter.recover();

      // 3. Provider changesSince + JournalReader.refresh + revocation check
      final changesCursor = await store.getMeta('changesCursor');
      final changes = await provider.changesSince(changesCursor);
      final Set<String>? changedKeys =
          (changes.cursorWasReset || changesCursor == null)
          ? null
          : changes.changedKeys.toSet();

      await _journalReader.refresh(changedKeys: changedKeys);
      await store.setMeta('changesCursor', changes.cursor);

      final myCursor = await store.cursor(device.deviceId);
      if (myCursor?.revokedAfterSeq != null) {
        throw const DeviceRevokedException();
      }

      crashInjector?.call(CrashPoint.afterRemoteRefresh, null);

      final allEntries = await store.allEntries();
      final remoteHistory = RemoteHistory(allEntries);

      if (cancel != null && cancel.isCancelled) {
        return _buildReport(stopwatch.elapsed);
      }

      // 4. LocalScanner.scan
      _emitProgress(SyncProgressPhase.scanning);
      final isCaseInsensitive = await CaseSensitivity.isCaseInsensitive(
        fs,
        store,
      );
      final isWindows = Platform.isWindows;
      final rules = await _loadRules();

      final localMap = await LocalScanner(fs: fs, store: store).scan(rules);
      crashInjector?.call(CrashPoint.afterScan, null);

      if (cancel != null && cancel.isCancelled) {
        return _buildReport(stopwatch.elapsed);
      }

      // 5. Planner.plan
      _emitProgress(SyncProgressPhase.planning);
      final allBases = await store.allBases();
      final baseMap = {for (final b in allBases) VaultPath(b.path): b};
      final deleteDecisions = await _loadDeleteDecisions();

      final planInput = PlannerInput(
        local: localMap,
        base: baseMap,
        remote: remoteHistory,
        deviceId: device.deviceId,
        caseInsensitive: isCaseInsensitive,
        isWindows: isWindows,
        deleteDecisions: deleteDecisions,
        rules: rules,
      );

      final plan = Planner.plan(planInput);

      if (plan.heldDeletes.isNotEmpty) {
        await store.setMeta(
          'heldDeletes',
          jsonEncode(plan.heldDeletes.map((p) => p.value).toList()),
        );
      } else {
        await store.removeMeta('heldDeletes');
      }

      final nowMs = clock.now().toUtc().millisecondsSinceEpoch;
      await store.transaction(() async {
        for (final update in plan.baseUpdates) {
          switch (update) {
            case final BaseUpdateRemove r:
              await store.removeBase(r.path.value);
            case final BaseUpdateSet s:
              await store.putBase(
                BaseState(
                  path: s.path.value,
                  caseKey: s.path.caseKey,
                  hash: s.hash,
                  size: s.size,
                  mtime: s.mtime,
                  version: s.version,
                  blobKeys: s.blobKeys,
                  syncedAt: nowMs,
                ),
              );
          }
        }
      });

      // Stats counters
      var uploaded = 0;
      var downloaded = 0;
      var merged = 0;
      var conflicts = 0;
      var deletedLocal = 0;
      var deletedRemote = 0;
      var renamed = 0;
      var bytesUp = 0;
      var bytesDown = 0;
      final errors = <String>[];

      // 6. Local phase (phases 1–5)
      _emitProgress(SyncProgressPhase.applying);
      final localActions = plan.actions.where((a) => a.phase <= 5).toList();
      final remoteActions = plan.actions.where((a) => a.phase > 5).toList();
      final stagedUploads = <Upload>[];

      for (var i = 0; i < localActions.length; i++) {
        if (cancel != null && cancel.isCancelled) break;

        final action = localActions[i];
        _emitProgress(
          SyncProgressPhase.applying,
          filesDone: i,
          filesTotal: localActions.length,
          currentPath: action.path,
        );

        final result = await _executor.execute(action);
        bytesDown += result.bytesDown;
        stagedUploads.addAll(result.stagedUploads);

        if (result.status == ExecutionStatus.applied) {
          switch (action) {
            case RenameLocal _:
              renamed++;
            case DeleteLocal _:
              deletedLocal++;
            case Download _:
              downloaded++;
            case Merge _:
              // If the result action was ConflictCopy, count as conflict
              if (result.action is ConflictCopy) {
                conflicts++;
              } else {
                merged++;
              }
            case ConflictCopy _:
              conflicts++;
            default:
              break;
          }
        }
      }

      // 7. Upload phase
      _emitProgress(SyncProgressPhase.uploading);
      final allUploads = [
        ...remoteActions.whereType<Upload>(),
        ...stagedUploads,
      ];

      for (var i = 0; i < allUploads.length; i++) {
        if (cancel != null && cancel.isCancelled) break;

        final upload = allUploads[i];
        _emitProgress(
          SyncProgressPhase.uploading,
          filesDone: i,
          filesTotal: allUploads.length,
          currentPath: upload.path,
        );

        try {
          final result = await _executor.execute(upload);
          if (result.status == ExecutionStatus.applied) {
            uploaded++;
            bytesUp += result.bytesUp;
          }
        } on RemoteQuotaExceededException catch (e) {
          _logger.warning(
            'Remote quota exceeded uploading ${upload.path.value}: $e',
          );
          errors.add('RemoteQuotaExceededException: ${upload.path.value}');
          // Staged upload dropped; local phase is preserved and retried next cycle
        } on SimulatedCrash {
          rethrow;
        } catch (e) {
          _logger.warning('Failed uploading ${upload.path.value}: $e');
          errors.add('$e');
        }
      }

      for (final action in remoteActions) {
        if (cancel != null && cancel.isCancelled) break;

        if (action is RenameRemote) {
          final result = await _executor.execute(action);
          if (result.status == ExecutionStatus.applied) {
            renamed++;
          }
        } else if (action is DeleteRemote) {
          final result = await _executor.execute(action);
          if (result.status == ExecutionStatus.applied) {
            deletedRemote++;
          }
        }
      }

      // 8. Commit
      _emitProgress(SyncProgressPhase.committing);
      while (_journalWriter.staged.isNotEmpty) {
        try {
          final batch = await _journalWriter.commit();
          if (batch != null) {
            await _afterCommitStateUpdate(batch);
            crashInjector?.call(CrashPoint.afterCommitStateUpdate, null);
          }
        } on RemoteQuotaExceededException catch (e) {
          _logger.warning('Remote quota exceeded committing journal batch: $e');
          errors.add('RemoteQuotaExceededException during commit');
          break;
        } on SimulatedCrash {
          rethrow;
        } catch (e) {
          _logger.severe('Error committing journal batch: $e');
          errors.add('Commit error: $e');
          break;
        }
      }

      // 9. Post-cycle: snapshot if due, heartbeat, trim log, lastSyncAt
      crashInjector?.call(CrashPoint.beforeSnapshot, null);
      try {
        final latestAllEntries = await store.allEntries();
        final latestHistory = RemoteHistory(latestAllEntries);
        final lastSeq =
            int.tryParse(await store.getMeta('nextSeq') ?? '1') ?? 1;
        final cursors = await store.allCursors();
        final covers = {for (final c in cursors) c.deviceId: c.lastSeq};
        await _snapshotStore.maybeSnapshot(
          lastSeq: lastSeq - 1,
          history: latestHistory,
          covers: covers,
        );
      } catch (e) {
        _logger.warning('Compacted snapshot check failed: $e');
      }

      try {
        await _deviceRegistry.heartbeat(device);
      } catch (e) {
        _logger.warning('Device heartbeat failed: $e');
      }

      final finishTime = clock.now().toUtc();
      await store.setMeta(
        'lastSyncAt',
        finishTime.millisecondsSinceEpoch.toString(),
      );

      crashInjector?.call(CrashPoint.cycleEnd, null);
      _emitProgress(SyncProgressPhase.done);

      return SyncReport(
        uploaded: uploaded,
        downloaded: downloaded,
        merged: merged,
        conflicts: conflicts,
        deletedLocal: deletedLocal,
        deletedRemote: deletedRemote,
        renamed: renamed,
        heldDeletes: plan.heldDeletes.length,
        bytesUp: bytesUp,
        bytesDown: bytesDown,
        duration: stopwatch.elapsed,
        errors: errors,
      );
    } finally {
      await lock.release();
    }
  }

  /// Records user decisions regarding deletions held by the delete guard.
  Future<void> decideHeldDeletes(
    Map<VaultPath, DeleteDecision> decisions,
  ) async {
    final existing = Map<VaultPath, DeleteDecision>.from(
      await _loadDeleteDecisions(),
    );
    existing.addAll(decisions);
    await store.setMeta(
      'deleteDecisions',
      jsonEncode({for (final e in existing.entries) e.key.value: e.value.name}),
    );
  }

  /// Closes progress and log streams and releases resources.
  Future<void> dispose() async {
    await _progressController.close();
    await _logController.close();
    if (lock.isHeld) {
      await lock.release();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  Future<void> _afterCommitStateUpdate(JournalBatch batch) async {
    final nowMs = clock.now().toUtc().millisecondsSinceEpoch;
    await store.transaction(() async {
      for (final entry in batch.entries) {
        if (entry.op == 'put') {
          final stat = await fs.stat(VaultPath(entry.path));
          await store.putBase(
            BaseState(
              path: entry.path,
              caseKey: VaultPath(entry.path).caseKey,
              hash: entry.hash!,
              size: entry.size ?? stat?.size ?? 0,
              mtime: entry.mtime ?? stat?.modified.millisecondsSinceEpoch ?? 0,
              version: entry.id,
              blobKeys: entry.blobKeys ?? const [],
              syncedAt: nowMs,
            ),
          );
        } else if (entry.op == 'delete') {
          await store.removeBase(entry.path);
        } else if (entry.op == 'move') {
          if (entry.fromPath != null) {
            await store.removeBase(entry.fromPath!);
          }
          final stat = await fs.stat(VaultPath(entry.path));
          await store.putBase(
            BaseState(
              path: entry.path,
              caseKey: VaultPath(entry.path).caseKey,
              hash: entry.hash!,
              size: entry.size ?? stat?.size ?? 0,
              mtime: entry.mtime ?? stat?.modified.millisecondsSinceEpoch ?? 0,
              version: entry.id,
              blobKeys: entry.blobKeys ?? const [],
              syncedAt: nowMs,
            ),
          );
        }
      }
    });
  }

  Future<SelectiveSyncRules> _loadRules() async {
    final rulesJson = await store.getMeta('selectiveSyncRules');
    if (rulesJson == null) return const SelectiveSyncRules();
    try {
      return SelectiveSyncRules.fromJson(
        jsonDecode(rulesJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SelectiveSyncRules();
    }
  }

  Future<Map<VaultPath, DeleteDecision>> _loadDeleteDecisions() async {
    final raw = await store.getMeta('deleteDecisions');
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <VaultPath, DeleteDecision>{};
      for (final e in map.entries) {
        final dec = DeleteDecision.values.firstWhere(
          (d) => d.name == e.value,
          orElse: () => DeleteDecision.keep,
        );
        result[VaultPath(e.key)] = dec;
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  void _emitProgress(
    SyncProgressPhase phase, {
    int filesDone = 0,
    int filesTotal = 0,
    int bytesDone = 0,
    int bytesTotal = 0,
    VaultPath? currentPath,
  }) {
    final now = clock.now();
    if (phase != SyncProgressPhase.done &&
        _lastProgressEmit != null &&
        now.difference(_lastProgressEmit!).inMilliseconds < 100) {
      return;
    }
    _lastProgressEmit = now;

    if (!_progressController.isClosed) {
      _progressController.add(
        SyncProgress(
          phase: phase,
          filesDone: filesDone,
          filesTotal: filesTotal,
          bytesDone: bytesDone,
          bytesTotal: bytesTotal,
          currentPath: currentPath,
        ),
      );
    }
  }

  SyncReport _buildReport(Duration elapsed) {
    return SyncReport(duration: elapsed);
  }
}
