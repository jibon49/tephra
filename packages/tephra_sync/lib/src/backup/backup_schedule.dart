// © 2026 Tephra. All rights reserved.

/// Configured frequency for automated vault backups.
enum BackupScheduleFrequency {
  /// Automatic backups disabled.
  off,

  /// Backup once every hour.
  hourly,

  /// Backup once every 24 hours, or when the local date advances past 03:00 AM.
  daily,

  /// Backup once every 7 days.
  weekly;

  /// Parses a schedule from a configuration string.
  static BackupScheduleFrequency fromString(String? val) {
    return switch (val?.toLowerCase().trim()) {
      'hourly' => BackupScheduleFrequency.hourly,
      'daily' => BackupScheduleFrequency.daily,
      'weekly' => BackupScheduleFrequency.weekly,
      _ => BackupScheduleFrequency.off,
    };
  }

  /// Serializes schedule to standard configuration string.
  String toJson() => name;
}

/// Evaluates whether an automated backup is due based on schedule and last run.
final class BackupSchedule {
  const BackupSchedule._();

  /// Determines if a backup is due at [now] given [lastBackupAt] and [schedule].
  static bool isDue(
    DateTime now,
    DateTime? lastBackupAt,
    BackupScheduleFrequency schedule,
  ) {
    if (schedule == BackupScheduleFrequency.off) {
      return false;
    }

    if (lastBackupAt == null) {
      return true;
    }

    // Guard against negative differences if device clock jumped backwards
    if (now.isBefore(lastBackupAt)) {
      return false;
    }

    final elapsed = now.difference(lastBackupAt);

    switch (schedule) {
      case BackupScheduleFrequency.off:
        return false;

      case BackupScheduleFrequency.hourly:
        return elapsed >= const Duration(hours: 1);

      case BackupScheduleFrequency.daily:
        if (elapsed >= const Duration(hours: 24)) {
          return true;
        }

        final localNow = now.toLocal();
        final localLast = lastBackupAt.toLocal();

        final dateChanged =
            localNow.year != localLast.year ||
            localNow.month != localLast.month ||
            localNow.day != localLast.day;

        return dateChanged && localNow.hour >= 3;

      case BackupScheduleFrequency.weekly:
        return elapsed >= const Duration(days: 7);
    }
  }
}
