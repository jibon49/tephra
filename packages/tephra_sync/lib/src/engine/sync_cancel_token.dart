// © 2026 Tephra. All rights reserved.

/// Token used to request graceful cancellation of an in-progress synchronization cycle.
final class SyncCancelToken {
  bool _isCancelled = false;

  /// True if cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Signals that the active sync cycle should cancel gracefully at the next safe boundary.
  void cancel() {
    _isCancelled = true;
  }
}
