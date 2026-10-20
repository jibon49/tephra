// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('HistoryRetention', () {
    const retention = HistoryRetention();
    final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

    JournalEntry makeEntry({
      required String entryId,
      required String path,
      required int daysAgo,
      int hour = 12,
      String op = 'put',
      String? parent,
      String? hash,
      List<String>? blobKeys,
    }) {
      final time = now.subtract(Duration(days: daysAgo, hours: 12 - hour));
      final hlc = Hlc(
        millis: time.millisecondsSinceEpoch,
        counter: 1,
        deviceId: 'dev1',
      ).encoded;
      return JournalEntry(
        entryId: entryId,
        deviceId: 'dev1',
        seq: 1,
        hlc: hlc,
        op: op,
        path: path,
        time: time.millisecondsSinceEpoch,
        parent: parent,
        hash: hash,
        blobKeys: blobKeys,
      );
    }

    test(
      'table test across ages (1, 29, 31, 200, 364, 366 days) with heads kept',
      () {
        final path = 'Notes/Work.md';

        // Build chain from oldest to newest:
        // Entry at 400 days ago (head will be newer)
        // Entry at 366 days ago
        // Entry at 364 days ago
        // Entry at 200 days ago
        // Entry at 31 days ago (morning)
        // Entry at 31 days ago (evening - newer)
        // Entry at 29 days ago
        // Entry at 1 day ago (head)
        final e366 = makeEntry(
          entryId: 'dev1:1',
          path: path,
          daysAgo: 366,
          hash: 'h366',
        );
        final e364 = makeEntry(
          entryId: 'dev1:2',
          path: path,
          daysAgo: 364,
          parent: 'dev1:1',
          hash: 'h364',
        );
        final e200 = makeEntry(
          entryId: 'dev1:3',
          path: path,
          daysAgo: 200,
          parent: 'dev1:2',
          hash: 'h200',
        );
        final e31M = makeEntry(
          entryId: 'dev1:4',
          path: path,
          daysAgo: 31,
          hour: 9,
          parent: 'dev1:3',
          hash: 'h31M',
        );
        final e31E = makeEntry(
          entryId: 'dev1:5',
          path: path,
          daysAgo: 31,
          hour: 18,
          parent: 'dev1:4',
          hash: 'h31E',
        );
        final e29 = makeEntry(
          entryId: 'dev1:6',
          path: path,
          daysAgo: 29,
          parent: 'dev1:5',
          hash: 'h29',
        );
        final e1 = makeEntry(
          entryId: 'dev1:7',
          path: path,
          daysAgo: 1,
          parent: 'dev1:6',
          hash: 'h1',
        );

        final history = RemoteHistory([e366, e364, e200, e31M, e31E, e29, e1]);
        final retained = retention.retainEntriesForPath(
          path: path,
          history: history,
          now: now,
        );

        // Verify each age:
        // Age 1 day (<30d): kept
        expect(retained.contains('dev1:7'), isTrue, reason: 'age 1 day');
        // Age 29 days (<30d): kept
        expect(retained.contains('dev1:6'), isTrue, reason: 'age 29 days');
        // Age 31 days (evening, newer): kept
        expect(
          retained.contains('dev1:5'),
          isTrue,
          reason: 'age 31 days newest',
        );
        // Age 31 days (morning, duplicate day): dropped
        expect(
          retained.contains('dev1:4'),
          isFalse,
          reason: 'age 31 days duplicate dropped',
        );
        // Age 200 days (30..365d): kept
        expect(retained.contains('dev1:3'), isTrue, reason: 'age 200 days');
        // Age 364 days (30..365d): kept
        expect(retained.contains('dev1:2'), isTrue, reason: 'age 364 days');
        // Age 366 days (>365d): dropped
        expect(
          retained.contains('dev1:1'),
          isFalse,
          reason: 'age 366 days dropped',
        );
      },
    );

    test('always keeps head even when older than 365 days', () {
      final path = 'Notes/Ancient.md';
      // Single head entry at age 450 days
      final ancientHead = makeEntry(
        entryId: 'dev1:100',
        path: path,
        daysAgo: 450,
        hash: 'hAncient',
      );

      final history = RemoteHistory([ancientHead]);
      final retained = retention.retainEntriesForPath(
        path: path,
        history: history,
        now: now,
      );

      expect(retained, contains('dev1:100'));
    });

    test('retains last put before delete within retention', () {
      final path = 'Notes/DeletedNote.md';

      // 1. Put at 370 days ago (dropped)
      final eOld = makeEntry(
        entryId: 'dev1:10',
        path: path,
        daysAgo: 370,
        hash: 'hOld',
      );
      // 2. Put at 150 days ago (kept as last put before delete)
      final eLastPut = makeEntry(
        entryId: 'dev1:11',
        path: path,
        daysAgo: 150,
        parent: 'dev1:10',
        hash: 'hLast',
      );
      // 3. Delete at 20 days ago (head - kept)
      final eDelete = makeEntry(
        entryId: 'dev1:12',
        path: path,
        daysAgo: 20,
        op: 'delete',
        parent: 'dev1:11',
      );

      final history = RemoteHistory([eOld, eLastPut, eDelete]);
      final retained = retention.retainEntriesForPath(
        path: path,
        history: history,
        now: now,
      );

      // Head delete is kept
      expect(retained, contains('dev1:12'));
      // Last put is kept (150 days ago <= 365 days)
      expect(retained, contains('dev1:11'));
      // Older put (>365 days) is dropped
      expect(retained, isNot(contains('dev1:10')));
    });
  });
}
