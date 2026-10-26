// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/deep_links/deep_link.dart';
import 'package:tephra/core/platform/notification_service.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra/stickies/reminders/reminder_ids.dart';
import 'package:tephra/stickies/reminders/reminder_ledger.dart';
import 'package:tephra/stickies/reminders/reminder_scheduler.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeNotificationService implements NotificationService {
  final List<ScheduledReminder> scheduled = [];
  final List<int> cancelled = [];

  void reset() {
    scheduled.clear();
    cancelled.clear();
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStickyRepository implements StickyRepository {
  List<Sticky> stickies = [];
  final StreamController<StickyChange> _changes =
      StreamController<StickyChange>.broadcast();

  @override
  List<Sticky> get all => List.unmodifiable(stickies);

  @override
  Stream<StickyChange> get changes => _changes.stream;

  @override
  Future<void> dispose() async {
    await _changes.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('ReminderScheduler', () {
    late tz.Location location;
    late Clock clock;
    late FakeNotificationService notifications;
    late FakeStickyRepository repo;
    late MemoryReminderLedger ledger;
    late ReminderScheduler scheduler;
    const vaultId = 'test-vault-123';

    setUp(() {
      location = tz.getLocation('Asia/Dhaka');
      // Fixed clock: 2026-10-11 09:30 Dhaka time (UTC+6 = 2026-10-11 03:30:00Z)
      clock = ManualClock(DateTime.utc(2026, 10, 11, 3, 30));
      notifications = FakeNotificationService();
      repo = FakeStickyRepository();
      ledger = MemoryReminderLedger();
      scheduler = ReminderScheduler(
        notifications: notifications,
        repo: repo,
        vaultId: vaultId,
        location: location,
        clock: clock,
        ledger: ledger,
      );
    });

    test('schedules future reminders only', () async {
      final pastTime = const LocalDateTime(
        2026,
        10,
        11,
        9,
        0,
      ); // 30 min in past
      final tooFarTime = const LocalDateTime(2027, 10, 15, 9, 30); // > 366 days
      final validFuture = const LocalDateTime(2026, 10, 12, 10, 0); // tomorrow

      repo.stickies = [
        Sticky(
          path: VaultPath('Stickies/Past.md'),
          meta: StickyMeta(isSticky: true, remind: pastTime),
          text: 'Past note content',
          hash: 'hash-past',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
        Sticky(
          path: VaultPath('Stickies/Far.md'),
          meta: StickyMeta(isSticky: true, remind: tooFarTime),
          text: 'Far future content',
          hash: 'hash-far',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
        Sticky(
          path: VaultPath('Stickies/Valid.md'),
          meta: StickyMeta(isSticky: true, remind: validFuture),
          text: 'Line 1 of body\nLine 2',
          hash: 'hash-valid',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();

      expect(notifications.scheduled.length, equals(1));
      expect(notifications.scheduled.first.title, equals('Valid'));
      expect(notifications.scheduled.first.body, equals('Line 1 of body'));
      expect(
        notifications.scheduled.first.at,
        equals(DateTime.utc(2026, 10, 12, 4, 0)),
      );

      final entries = ledger.getEntries(vaultId);
      expect(entries.length, equals(1));
      expect(entries.values.first.path.value, equals('Stickies/Valid.md'));
    });

    test('reconcile is idempotent', () async {
      repo.stickies = [
        Sticky(
          path: VaultPath('Stickies/Task.md'),
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Buy milk',
          hash: 'hash1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();
      expect(notifications.scheduled.length, equals(1));

      // Second run: no new calls to schedule or cancel
      notifications.reset();
      await scheduler.reconcile();
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelled, isEmpty);
    });

    test('changed time cancels then schedules', () async {
      final path = VaultPath('Stickies/Meeting.md');
      final id = reminderId(vaultId, path);

      repo.stickies = [
        Sticky(
          path: path,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Meeting at 9',
          hash: 'hash1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();
      expect(notifications.scheduled.length, equals(1));
      notifications.reset();

      // Change time to 14:00
      repo.stickies = [
        Sticky(
          path: path,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 14, 0),
          ),
          text: 'Meeting moved to 2pm',
          hash: 'hash2',
          modified: DateTime.utc(2026, 10, 11, 4, 0),
        ),
      ];

      await scheduler.reconcile();

      expect(notifications.cancelled, contains(id));
      expect(notifications.scheduled.length, equals(1));
      expect(
        notifications.scheduled.first.at,
        equals(DateTime.utc(2026, 10, 12, 8, 0)),
      );
    });

    test('unpinned sticky cancels reminder', () async {
      final path = VaultPath('Stickies/Pinned.md');
      final id = reminderId(vaultId, path);

      repo.stickies = [
        Sticky(
          path: path,
          meta: const StickyMeta(
            isSticky: true,
            pinned: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Pinned note with reminder',
          hash: 'h1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();
      expect(notifications.scheduled.length, equals(1));
      notifications.reset();

      // Sticky is unpinned / removed from active stickies
      repo.stickies = [];
      await scheduler.reconcile();

      expect(notifications.cancelled, contains(id));
      expect(ledger.getEntries(vaultId), isEmpty);
    });

    test('renamed sticky gets new id and old id is cancelled', () async {
      final oldPath = VaultPath('Stickies/OldName.md');
      final newPath = VaultPath('Stickies/NewName.md');
      final oldId = reminderId(vaultId, oldPath);
      final newId = reminderId(vaultId, newPath);

      repo.stickies = [
        Sticky(
          path: oldPath,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Remember to call Alice',
          hash: 'h1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();
      expect(notifications.scheduled.first.id, equals(oldId));
      notifications.reset();

      // Renamed to NewName.md
      repo.stickies = [
        Sticky(
          path: newPath,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Remember to call Alice',
          hash: 'h1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();

      expect(notifications.cancelled, contains(oldId));
      expect(notifications.scheduled.map((r) => r.id), contains(newId));

      final entries = ledger.getEntries(vaultId);
      expect(entries.containsKey(oldId), isFalse);
      expect(entries.containsKey(newId), isTrue);
    });

    test('disabled setting cancels all', () async {
      final p1 = VaultPath('Stickies/One.md');
      final p2 = VaultPath('Stickies/Two.md');
      final id1 = reminderId(vaultId, p1);
      final id2 = reminderId(vaultId, p2);

      repo.stickies = [
        Sticky(
          path: p1,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Note 1',
          hash: 'h1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
        Sticky(
          path: p2,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 10, 0),
          ),
          text: 'Note 2',
          hash: 'h2',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();
      expect(notifications.scheduled.length, equals(2));
      notifications.reset();

      // Disable reminders
      scheduler.enabled = false;
      await scheduler.reconcile();

      expect(notifications.cancelled, containsAll([id1, id2]));
      expect(ledger.getEntries(vaultId), isEmpty);
    });

    test('payload is an open deep link', () async {
      final path = VaultPath('Stickies/Work Note.md');
      repo.stickies = [
        Sticky(
          path: path,
          meta: const StickyMeta(
            isSticky: true,
            remind: LocalDateTime(2026, 10, 12, 9, 0),
          ),
          text: 'Work tasks to do',
          hash: 'h1',
          modified: DateTime.utc(2026, 10, 11, 3, 0),
        ),
      ];

      await scheduler.reconcile();

      expect(notifications.scheduled.length, equals(1));
      final payload = notifications.scheduled.first.payload;
      final parsed = DeepLink.parse(Uri.parse(payload));
      expect(parsed, isA<OpenNoteLink>());
      final openLink = parsed as OpenNoteLink;
      expect(openLink.vaultId, equals(vaultId));
      expect(openLink.path, equals(path));
    });
  });
}
