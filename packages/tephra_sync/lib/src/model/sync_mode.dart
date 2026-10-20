// © 2026 Tephra. All rights reserved.

/// Operating mode of vault synchronization.
enum SyncMode {
  /// Automatic bidirectional sync of notes, files, and settings.
  live('live'),

  /// Upload-only scheduled backups without syncing changes down.
  backupOnly('backupOnly'),

  /// Sync and automated backups are disabled.
  off('off');

  const SyncMode(this.value);

  /// String representation stored in sync metadata.
  final String value;

  /// Parses a [SyncMode] from [value], defaulting to [off] if unknown.
  static SyncMode fromString(String? value) {
    return switch (value) {
      'live' => SyncMode.live,
      'backupOnly' => SyncMode.backupOnly,
      _ => SyncMode.off,
    };
  }
}
