// © 2026 Tephra. All rights reserved.

/// Moves an absolute path to the operating system's recycle bin. Pure Dart cannot do this, so the app supplies the implementation.
abstract interface class SystemTrash {
  /// Returns true when the item was moved to the OS trash; false when the platform cannot (caller falls back to the vault trash).
  Future<bool> moveToTrash(String absolutePath, {required bool isFolder});
}
