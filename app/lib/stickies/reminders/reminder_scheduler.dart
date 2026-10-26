// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/deep_links/deep_link.dart';
import '../../core/platform/notification_service.dart';
import '../data/sticky_repository.dart';
import 'reminder_ids.dart';
import 'reminder_ledger.dart';
import 'reminder_time.dart';

final class _DesiredReminder {
  const _DesiredReminder({
    required this.id,
    required this.path,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final VaultPath path;
  final DateTime at;
  final String title;
  final String body;
  final String payload;
}

/// Schedules and reconciles system notifications for sticky note reminders.
final class ReminderScheduler {
  ReminderScheduler({
    required this.notifications,
    required this.repo,
    required this.vaultId,
    required this.location,
    required this.clock,
    required this.ledger,
    this.enabled = true,
  });

  final NotificationService notifications;
  final StickyRepository repo;
  final String vaultId;
  tz.Location location;
  final Clock clock;
  final ReminderLedger ledger;
  bool enabled;

  StreamSubscription<StickyChange>? _changesSub;
  Timer? _debounceTimer;
  Future<void>? _runningReconcile;

  /// Starts listening to changes on [repo] and automatically reconciling.
  void start() {
    _changesSub?.cancel();
    _changesSub = repo.changes.listen((change) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        reconcile();
      });
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _changesSub?.cancel();
  }

  /// Extracts the first non-empty line of the sticky body, truncated to 120 characters.
  static String extractBody(String fullBody) {
    for (final line in fullBody.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.length > 120) {
          return trimmed.substring(0, 120);
        }
        return trimmed;
      }
    }
    return '';
  }

  /// Reconciles desired reminders from active stickies against the [ledger].
  Future<void> reconcile() async {
    while (_runningReconcile != null) {
      await _runningReconcile;
    }
    final c = Completer<void>();
    _runningReconcile = c.future;
    try {
      await _doReconcile();
    } finally {
      _runningReconcile = null;
      c.complete();
    }
  }

  Future<void> _doReconcile() async {
    final scheduled = ledger.getEntries(vaultId);

    if (!enabled) {
      for (final id in scheduled.keys) {
        await notifications.cancel(id);
      }
      await ledger.saveEntries(vaultId, const {});
      return;
    }

    final nowUtc = clock.now().toUtc();
    final desired = <int, _DesiredReminder>{};

    for (final sticky in repo.all) {
      final remind = sticky.meta.remind;
      if (remind == null) continue;

      final instant = resolveWallTime(remind, location);
      final diff = instant.difference(nowUtc);

      // Instant must be more than 5s in the future and less than 366 days ahead.
      if (diff.inSeconds <= 5 || diff.inDays >= 366) {
        continue;
      }

      final id = reminderId(vaultId, sticky.path);
      final title = sticky.title;
      final body = extractBody(sticky.body);
      final payload = OpenNoteLink(
        vaultId: vaultId,
        path: sticky.path,
      ).toUri().toString();

      desired[id] = _DesiredReminder(
        id: id,
        path: sticky.path,
        at: instant,
        title: title,
        body: body,
        payload: payload,
      );
    }

    final newScheduled = Map<int, ReminderEntry>.from(scheduled);

    // Cancel ids in the ledger not desired or with a different `at`.
    for (final entry in scheduled.entries) {
      final id = entry.key;
      final existing = entry.value;
      final target = desired[id];
      if (target == null || !target.at.isAtSameMomentAs(existing.at)) {
        await notifications.cancel(id);
        newScheduled.remove(id);
      }
    }

    // Schedule desired ids that are new or changed.
    for (final target in desired.values) {
      final existing = scheduled[target.id];
      if (existing == null || !existing.at.isAtSameMomentAs(target.at)) {
        await notifications.schedule(
          ScheduledReminder(
            id: target.id,
            at: target.at,
            title: target.title,
            body: target.body,
            payload: target.payload,
          ),
        );
        newScheduled[target.id] = ReminderEntry(
          path: target.path,
          at: target.at,
        );
      }
    }

    await ledger.saveEntries(vaultId, newScheduled);
  }
}
