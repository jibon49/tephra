// © 2026 Tephra. All rights reserved.

import 'backup_manifest.dart';

/// Configurable retention counts for keeping point-in-time vault backups.
final class BackupRetentionSettings {
  /// Creates [BackupRetentionSettings].
  const BackupRetentionSettings({
    this.hourly = 48,
    this.daily = 30,
    this.monthly = 12,
  });

  /// Parses retention settings from JSON.
  factory BackupRetentionSettings.fromJson(Map<String, dynamic> json) {
    return BackupRetentionSettings(
      hourly: (json['hourly'] as num?)?.toInt() ?? 48,
      daily: (json['daily'] as num?)?.toInt() ?? 30,
      monthly: (json['monthly'] as num?)?.toInt() ?? 12,
    );
  }

  /// Number of distinct recent hourly buckets to preserve (default 48).
  final int hourly;

  /// Number of distinct recent daily buckets to preserve (default 30).
  final int daily;

  /// Number of distinct recent monthly buckets to preserve (default 12).
  final int monthly;

  /// Serializes retention settings to a JSON map.
  Map<String, dynamic> toJson() => {
    'hourly': hourly,
    'daily': daily,
    'monthly': monthly,
  };
}

/// Pure algorithm for selecting the retained subset of vault backups.
final class BackupRetention {
  const BackupRetention._();

  /// Evaluates [stamps] against the retention policy and returns the Set of timestamps to keep.
  ///
  /// Policy:
  /// 1. Sort newest first.
  /// 2. Always keep the newest backup.
  /// 3. Keep the newest backup in each of the most recent [hourly] distinct UTC hour buckets.
  /// 4. Keep the newest backup in each of the most recent [daily] distinct UTC day buckets.
  /// 5. Keep the newest backup in each of the most recent [monthly] distinct UTC month buckets.
  /// 6. Union all buckets.
  /// 7. Keep every [preRestoreStamps] backup younger than 30 days.
  static Set<DateTime> select(
    List<DateTime> stamps, {
    int hourly = 48,
    int daily = 30,
    int monthly = 12,
    Iterable<DateTime> preRestoreStamps = const [],
    DateTime? now,
  }) {
    if (stamps.isEmpty && preRestoreStamps.isEmpty) {
      return const <DateTime>{};
    }

    final sorted = List<DateTime>.from(stamps)
      ..sort((a, b) => b.compareTo(a)); // Newest first

    final kept = <DateTime>{};
    if (sorted.isNotEmpty) {
      kept.add(sorted.first);
    }

    // 1. Hourly buckets (most recent `hourly` distinct UTC hours)
    final seenHours = <String>{};
    for (final s in sorted) {
      final u = s.toUtc();
      final key = '${u.year}-${u.month}-${u.day}-${u.hour}';
      if (!seenHours.contains(key)) {
        if (seenHours.length < hourly) {
          seenHours.add(key);
          kept.add(s);
        }
      }
    }

    // 2. Daily buckets (most recent `daily` distinct UTC days)
    final seenDays = <String>{};
    for (final s in sorted) {
      final u = s.toUtc();
      final key = '${u.year}-${u.month}-${u.day}';
      if (!seenDays.contains(key)) {
        if (seenDays.length < daily) {
          seenDays.add(key);
          kept.add(s);
        }
      }
    }

    // 3. Monthly buckets (most recent `monthly` distinct UTC months)
    final seenMonths = <String>{};
    for (final s in sorted) {
      final u = s.toUtc();
      final key = '${u.year}-${u.month}';
      if (!seenMonths.contains(key)) {
        if (seenMonths.length < monthly) {
          seenMonths.add(key);
          kept.add(s);
        }
      }
    }

    // 4. Pre-restore backups younger than 30 days
    final referenceNow =
        now?.toUtc() ??
        (sorted.isNotEmpty ? sorted.first.toUtc() : DateTime.now().toUtc());
    const thirtyDays = Duration(days: 30);

    for (final pr in preRestoreStamps) {
      final diff = referenceNow.difference(pr.toUtc());
      if (diff >= Duration.zero && diff < thirtyDays) {
        kept.add(pr);
      }
    }

    return kept;
  }

  /// Selects manifests to retain from a list of [BackupManifest] instances.
  ///
  /// Returns the Set of retained manifest stamps (`yyyyMMddTHHmmssZ`).
  static Set<String> selectManifests(
    List<BackupManifest> manifests, {
    int hourly = 48,
    int daily = 30,
    int monthly = 12,
    DateTime? now,
  }) {
    final stamps = manifests.map((m) => m.createdAt).toList();
    final preRestores = manifests
        .where((m) => m.kind == BackupKind.preRestore)
        .map((m) => m.createdAt)
        .toList();

    final keptDates = select(
      stamps,
      hourly: hourly,
      daily: daily,
      monthly: monthly,
      preRestoreStamps: preRestores,
      now: now,
    );

    return keptDates.map(BackupManifest.formatStamp).toSet();
  }
}
