// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';
import 'package:tephra_sync/tephra_sync.dart';

class FakeSyncWorkerClient extends SyncWorkerClient {
  FakeSyncWorkerClient({
    SyncStatusSnapshot initialStatus = const SyncStatusSnapshot(
      state: SyncUiState.idle,
    ),
    List<SyncLogEntry>? initialLogs,
    List<RemoteDevice>? initialDevices,
  }) : _status = initialStatus,
       logs = initialLogs ?? [],
       devices = initialDevices ?? [],
       super(
         workerSendPort: ReceivePort().sendPort,
         receivePort: ReceivePort(),
       );

  SyncStatusSnapshot _status;
  final StreamController<SyncStatusSnapshot> _statusCtrl =
      StreamController<SyncStatusSnapshot>.broadcast();
  final StreamController<SyncProgress> _progressCtrl =
      StreamController<SyncProgress>.broadcast();
  final StreamController<SyncLogEntry> _logCtrl =
      StreamController<SyncLogEntry>.broadcast();

  List<SyncLogEntry> logs;
  List<RemoteDevice> devices;

  int syncNowCallCount = 0;
  bool? lastPaused;
  Map<String, DeleteDecision>? lastHeldDeletes;
  SyncWorkerSettings? lastSettings;
  String? lastRevokedDeviceId;

  @override
  SyncStatusSnapshot get currentStatus => _status;

  @override
  Stream<SyncStatusSnapshot> get statusStream => _statusCtrl.stream;

  @override
  Stream<SyncProgress> get progressStream => _progressCtrl.stream;

  @override
  Stream<SyncLogEntry> get logStream => _logCtrl.stream;

  void emitStatus(SyncStatusSnapshot newStatus) {
    _status = newStatus;
    _statusCtrl.add(newStatus);
  }

  void emitProgress(SyncProgress progress) {
    _progressCtrl.add(progress);
  }

  void emitLog(SyncLogEntry entry) {
    logs.insert(0, entry);
    _logCtrl.add(entry);
  }

  @override
  Future<SyncReport?> syncNow({
    SyncTrigger trigger = SyncTrigger.manual,
  }) async {
    syncNowCallCount++;
    return const SyncReport(duration: Duration.zero);
  }

  @override
  Future<void> setPaused(bool paused) async {
    lastPaused = paused;
    emitStatus(
      _status.copyWith(state: paused ? SyncUiState.paused : SyncUiState.idle),
    );
  }

  @override
  Future<List<SyncLogEntry>> queryLog({int limit = 100}) async {
    return logs.take(limit).toList();
  }

  @override
  Future<List<RemoteDevice>> queryDevices() async {
    return devices;
  }

  @override
  Future<void> decideHeldDeletes(Map<String, DeleteDecision> decisions) async {
    lastHeldDeletes = decisions;
  }

  @override
  Future<void> updateSettings(SyncWorkerSettings settings) async {
    lastSettings = settings;
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    lastRevokedDeviceId = deviceId;
    devices = devices.map((d) {
      if (d.deviceId == deviceId) {
        return d.copyWith(revoked: true);
      }
      return d;
    }).toList();
  }

  @override
  Future<void> shutdown() async {
    await _statusCtrl.close();
    await _progressCtrl.close();
    await _logCtrl.close();
  }
}
