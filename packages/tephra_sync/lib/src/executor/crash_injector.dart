// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Named points during a synchronization cycle where simulated crashes can be injected.
enum CrashPoint {
  cycleStart,
  afterRemoteRefresh,
  afterScan,
  beforeLocalWrite,
  afterLocalWrite,
  afterLocalStateUpdate,
  beforeBlobUpload,
  afterBlobUpload,
  beforeJournalPut,
  afterJournalPut,
  afterCommitStateUpdate,
  beforeSnapshot,
  cycleEnd,
}

/// Exception thrown to simulate an unrecoverable process crash at a given [point].
final class SimulatedCrash implements Exception {
  const SimulatedCrash(this.point, [this.path]);

  /// The phase point at which the crash occurred.
  final CrashPoint point;

  /// Optional path being processed when the crash was triggered.
  final VaultPath? path;

  @override
  String toString() =>
      'SimulatedCrash at $point${path != null ? ' on ${path!.value}' : ''}';
}

/// Callback signature for intercepting execution at specific cycle points.
typedef CrashInjector = void Function(CrashPoint point, VaultPath? path);
