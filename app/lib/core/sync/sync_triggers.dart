// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

final _log = Logger('sync.triggers');

typedef TimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Manages event-driven triggers for starting synchronization cycles.
class SyncTriggers {
  SyncTriggers({
    required this.onTrigger,
    this.onLocalChange,
    this.clock = const SystemClock(),
    this.debounceDuration = const Duration(seconds: 5),
    this.pollInterval = const Duration(seconds: 30),
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? ((d, fn) => Timer(d, fn));

  final void Function(SyncTrigger trigger) onTrigger;
  final void Function(List<VaultPath> paths)? onLocalChange;
  final Clock clock;
  final Duration debounceDuration;
  final Duration pollInterval;
  final TimerFactory _timerFactory;

  Timer? _debounceTimer;
  Timer? _pollTimer;

  bool _isForeground = true;
  bool _keepRunningWhenClosed = false;
  bool _isSyncing = false;
  SyncTrigger? _runAgainTrigger;

  final Set<VaultPath> _pendingLocalChanges = {};

  bool get isSyncing => _isSyncing;
  bool get hasRunAgain => _runAgainTrigger != null;

  /// Called when a note is edited or saved locally.
  ///
  /// Debounces by [debounceDuration] (default 5 s) after the last change.
  void notifyLocalChange(VaultPath path) {
    _pendingLocalChanges.add(path);
    onLocalChange?.call([path]);

    _debounceTimer?.cancel();
    _debounceTimer = _timerFactory(debounceDuration, () {
      _pendingLocalChanges.clear();
      requestSync(SyncTrigger.save);
    });
  }

  /// Request a sync cycle with [trigger], honoring the "run again" coalescing policy.
  void requestSync(SyncTrigger trigger) {
    if (_isSyncing) {
      _log.info('Sync already in progress; scheduling run-again for $trigger');
      _runAgainTrigger = trigger;
      return;
    }

    _isSyncing = true;
    onTrigger(trigger);
  }

  /// Informs triggers that the active cycle has finished.
  ///
  /// If a trigger arrived while the cycle was running, immediately triggers one run-again cycle.
  void onCycleCompleted() {
    _isSyncing = false;
    final next = _runAgainTrigger;
    if (next != null) {
      _runAgainTrigger = null;
      requestSync(next);
    }
  }

  /// Called when the vault opens and engine starts.
  void onAppStart() {
    _isForeground = true;
    requestSync(SyncTrigger.appStart);
    _startPolling();
  }

  /// Called on [AppLifecycleState.resumed].
  void onAppResume() {
    _isForeground = true;
    requestSync(SyncTrigger.appResume);
    _startPolling();
  }

  /// Called on [AppLifecycleState.paused] or window hidden.
  void onAppPause() {
    _isForeground = false;
    if (!_keepRunningWhenClosed) {
      _stopPolling();
    }
  }

  /// Configures whether background polling continues when window is closed (Windows).
  void setKeepRunningWhenClosed(bool keepRunning) {
    _keepRunningWhenClosed = keepRunning;
    if (!_isForeground) {
      if (keepRunning) {
        _startPolling();
      } else {
        _stopPolling();
      }
    }
  }

  /// User-initiated sync action.
  void syncNow() {
    requestSync(SyncTrigger.manual);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = _timerFactory(pollInterval, () {
      if (_isForeground || _keepRunningWhenClosed) {
        requestSync(SyncTrigger.remotePoll);
        _startPolling();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _stopPolling();
    _pendingLocalChanges.clear();
  }
}
