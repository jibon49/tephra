// © 2026 Tephra. All rights reserved.

import 'dart:io';

/// Synchronization lock interface to ensure mutual exclusion across engines and isolates.
abstract interface class SyncLock {
  /// Attempts to acquire the lock without blocking.
  ///
  /// Returns `true` if acquired, `false` otherwise.
  Future<bool> tryAcquire();

  /// Releases the lock if currently held.
  Future<void> release();

  /// Returns `true` if this instance currently holds the lock.
  bool get isHeld;
}

/// In-memory lock implementation for testing and single-process coordination.
final class MemorySyncLock implements SyncLock {
  bool _held = false;

  @override
  bool get isHeld => _held;

  @override
  Future<bool> tryAcquire() async {
    if (_held) return false;
    _held = true;
    return true;
  }

  @override
  Future<void> release() async {
    _held = false;
  }
}

/// File-based lock implementation using non-blocking exclusive OS file locking.
final class FileSyncLock implements SyncLock {
  FileSyncLock(this.lockFilePath);

  /// Path to the lock file (e.g. `<appSupportDir>/sync/<vaultId>.lock`).
  final String lockFilePath;

  RandomAccessFile? _raf;

  @override
  bool get isHeld => _raf != null;

  @override
  Future<bool> tryAcquire() async {
    if (_raf != null) return true;

    try {
      final file = File(lockFilePath);
      final parent = file.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.lock(FileLock.exclusive);
        _raf = raf;
        return true;
      } catch (_) {
        await raf.close();
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> release() async {
    if (_raf != null) {
      try {
        await _raf!.unlock();
      } catch (_) {}
      try {
        await _raf!.close();
      } catch (_) {}
      _raf = null;
    }
  }
}
