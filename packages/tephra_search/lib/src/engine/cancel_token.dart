// © 2026 Tephra. All rights reserved.

/// Token used to request cancellation of an ongoing search operation.
final class CancelToken {
  bool _isCancelled = false;

  /// Returns true if cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation.
  void cancel() {
    _isCancelled = true;
  }
}
