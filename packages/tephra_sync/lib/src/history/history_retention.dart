// © 2026 Tephra. All rights reserved.

import '../model/journal_entry.dart';
import '../remote/remote_history.dart';

/// Pure retention evaluation for remote journal entries.
///
/// Constants:
/// - Keep all versions younger than [keepAllDays] (30 days).
/// - Between [keepAllDays] and [thinningDays] (30–365 days), keep the newest version per calendar day UTC.
/// - Drop versions older than [thinningDays] (365 days).
/// - Heads and leaves are always kept, regardless of age.
/// - For deleted files, the last put/move before the delete follows the same rule.
final class HistoryRetention {
  const HistoryRetention({this.keepAllDays = 30, this.thinningDays = 365});

  /// Days for which all historical versions are preserved without thinning.
  final int keepAllDays;

  /// Max days to preserve thinned versions (one per calendar day) before dropping.
  final int thinningDays;

  /// Evaluates retention for entries touching [path] in [history] relative to [now].
  ///
  /// Returns the set of retained entry IDs (`<deviceId>:<seq>`).
  Set<String> retainEntriesForPath({
    required String path,
    required RemoteHistory history,
    required DateTime now,
  }) {
    final retained = <String>{};

    // 1. Always keep leaves and head
    final leaves = history.leaves(path);
    for (final l in leaves) {
      retained.add(l.entryId);
    }
    final head = history.head(path);
    if (head != null) {
      retained.add(head.entryId);
    }

    // 2. Evaluate all versions touching path
    final versions = history.versions(path);
    final nowUtc = now.toUtc();
    final calendarDaysSeen = <String>{};

    // Find the last put/move before delete if head is a delete
    JournalEntry? lastPutBeforeDelete;
    if (head != null && head.op == 'delete') {
      for (final e in versions) {
        if (e.entryId != head.entryId && (e.op == 'put' || e.op == 'move')) {
          lastPutBeforeDelete = e;
          break;
        }
      }
    }

    for (final entry in versions) {
      if (retained.contains(entry.entryId)) {
        continue;
      }

      final entryTime = DateTime.fromMillisecondsSinceEpoch(
        entry.time,
        isUtc: true,
      );
      final age = nowUtc.difference(entryTime);

      final isLastPut = lastPutBeforeDelete?.entryId == entry.entryId;

      if (age < Duration(days: keepAllDays)) {
        // Younger than keepAllDays: keep all
        retained.add(entry.entryId);
      } else if (age <= Duration(days: thinningDays)) {
        // Between keepAllDays and thinningDays: keep newest per calendar day (UTC)
        final dayKey = '${entryTime.year}-${entryTime.month}-${entryTime.day}';
        if (calendarDaysSeen.add(dayKey)) {
          retained.add(entry.entryId);
        } else if (isLastPut) {
          retained.add(entry.entryId);
        }
      } else {
        // Older than thinningDays: drop (unless head/leaf, already added above)
      }
    }

    return retained;
  }

  /// Evaluates retention across all paths in [history] relative to [now].
  Set<String> retainAllEntries({
    required RemoteHistory history,
    required DateTime now,
  }) {
    final allRetained = <String>{};
    for (final path in history.allPaths) {
      allRetained.addAll(
        retainEntriesForPath(path: path, history: history, now: now),
      );
    }
    return allRetained;
  }
}
