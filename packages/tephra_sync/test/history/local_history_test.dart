// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('LocalHistory', () {
    late MemoryVaultFileSystem fs;
    late ManualClock clock;
    late LocalHistory history;

    setUp(() {
      fs = MemoryVaultFileSystem();
      clock = ManualClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
      history = LocalHistory(fs, clock);
    });

    test('snapshot naming and path.txt creation', () async {
      final path = VaultPath('Notes/Welcome.md');
      final content = utf8.encode('# Welcome to Tephra');

      await history.snapshot(path, content, reason: SnapshotReason.editing);

      final hash = LocalHistory.pathHash(path);
      final pathTxtPath = VaultPath('.tephra/history/$hash/path.txt');
      expect(await fs.stat(pathTxtPath), isNotNull);
      final pathTxtBytes = await fs.readBytes(pathTxtPath);
      expect(utf8.decode(pathTxtBytes), equals('Notes/Welcome.md'));

      final list = await history.list(path);
      expect(list.length, equals(1));
      expect(
        list.first,
        contains('.tephra/history/$hash/20261020T120000000Z.md.gz'),
      );

      final readBytes = await history.read(list.first);
      expect(readBytes, equals(content));
    });

    test('skips identical snapshot', () async {
      final path = VaultPath('Notes/Welcome.md');
      final content = utf8.encode('# Welcome');

      await history.snapshot(
        path,
        content,
        reason: SnapshotReason.beforeRestore,
      );

      // Advance clock by 1 hour
      clock.advance(const Duration(hours: 1));

      // Attempt identical content
      await history.snapshot(
        path,
        content,
        reason: SnapshotReason.beforeRestore,
      );

      final list = await history.list(path);
      expect(list.length, equals(1));
    });

    test('enforces 10-minute rule for editing snapshots', () async {
      final path = VaultPath('Notes/Daily.md');
      final content1 = utf8.encode('Edit 1');
      final content2 = utf8.encode('Edit 2');
      final content3 = utf8.encode('Edit 3');

      // 1. Initial snapshot
      await history.snapshot(path, content1, reason: SnapshotReason.editing);
      expect((await history.list(path)).length, equals(1));

      // 2. Edit after 5 minutes (< 10 mins) -> skipped
      clock.advance(const Duration(minutes: 5));
      await history.snapshot(path, content2, reason: SnapshotReason.editing);
      expect((await history.list(path)).length, equals(1));

      // 3. Edit after another 6 minutes (total 11 mins since last snapshot) -> captured
      clock.advance(const Duration(minutes: 6));
      await history.snapshot(path, content3, reason: SnapshotReason.editing);
      expect((await history.list(path)).length, equals(2));

      // 4. Non-editing snapshot (e.g. beforeSyncOverwrite) ignores 10-minute rule
      final content4 = utf8.encode('Edit 4');
      clock.advance(const Duration(minutes: 1));
      await history.snapshot(
        path,
        content4,
        reason: SnapshotReason.beforeSyncOverwrite,
      );
      expect((await history.list(path)).length, equals(3));
    });

    test(
      'prune handles 7-day, 30-day thinning and keeps newest per path',
      () async {
        final path = VaultPath('Notes/Archived.md');

        // Create snapshots across various dates:
        // - 40 days ago (older than 30 days)
        // - 35 days ago (older than 30 days)
        // - 20 days ago morning (between 7 and 30 days)
        // - 20 days ago evening (between 7 and 30 days - same day)
        // - 15 days ago (between 7 and 30 days)
        // - 3 days ago (younger than 7 days)
        // - 1 day ago (younger than 7 days)
        final base = DateTime.utc(2026, 10, 20, 12, 0, 0);

        void setTime(int daysAgo, int hour) {
          clock.set(base.subtract(Duration(days: daysAgo, hours: 12 - hour)));
        }

        setTime(40, 10);
        await history.snapshot(
          path,
          utf8.encode('v-40'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(35, 10);
        await history.snapshot(
          path,
          utf8.encode('v-35'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(20, 9);
        await history.snapshot(
          path,
          utf8.encode('v-20-morning'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(20, 18);
        await history.snapshot(
          path,
          utf8.encode('v-20-evening'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(15, 12);
        await history.snapshot(
          path,
          utf8.encode('v-15'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(3, 12);
        await history.snapshot(
          path,
          utf8.encode('v-3'),
          reason: SnapshotReason.beforeRestore,
        );

        setTime(1, 12);
        await history.snapshot(
          path,
          utf8.encode('v-1'),
          reason: SnapshotReason.beforeRestore,
        );

        clock.set(base);
        expect((await history.list(path)).length, equals(7));

        await history.prune();

        final remaining = await history.list(path);
        // Expected remaining:
        // - v-1 (1 day ago: kept, < 7d)
        // - v-3 (3 days ago: kept, < 7d)
        // - v-15 (15 days ago: kept, 7..30d)
        // - v-20-evening (20 days ago evening: newest for day 20, kept)
        // Dropped:
        // - v-20-morning (older on same calendar day)
        // - v-35 (> 30d)
        // - v-40 (> 30d)
        expect(remaining.length, equals(4));

        final contents = <String>[];
        for (final ref in remaining) {
          contents.add(utf8.decode((await history.read(ref))!));
        }
        expect(contents, containsAll(['v-1', 'v-3', 'v-15', 'v-20-evening']));
        expect(contents, isNot(contains('v-20-morning')));
        expect(contents, isNot(contains('v-35')));
        expect(contents, isNot(contains('v-40')));
      },
    );

    test(
      'prune preserves newest snapshot even if older than 30 days',
      () async {
        final path = VaultPath('Notes/OldNote.md');
        final base = DateTime.utc(2026, 10, 20, 12, 0, 0);

        clock.set(base.subtract(const Duration(days: 45)));
        await history.snapshot(
          path,
          utf8.encode('v-old-1'),
          reason: SnapshotReason.beforeRestore,
        );

        clock.set(base.subtract(const Duration(days: 40)));
        await history.snapshot(
          path,
          utf8.encode('v-old-2'),
          reason: SnapshotReason.beforeRestore,
        );

        clock.set(base);
        expect((await history.list(path)).length, equals(2));

        await history.prune();

        final remaining = await history.list(path);
        // Newest snapshot (v-old-2) is kept even though it is 40 days old
        expect(remaining.length, equals(1));
        expect(
          utf8.decode((await history.read(remaining.first))!),
          equals('v-old-2'),
        );
      },
    );

    test('prune enforces maxHistoryBytes size cap without deleting newest snapshots', () async {
      final pathA = VaultPath('Notes/NoteA.md');
      final pathB = VaultPath('Notes/NoteB.md');
      final base = DateTime.utc(2026, 10, 20, 12, 0, 0);

      // Path A: 3 snapshots within 3 days
      clock.set(base.subtract(const Duration(days: 3)));
      await history.snapshot(
        pathA,
        utf8.encode('content A1 ${'A' * 200}'),
        reason: SnapshotReason.beforeRestore,
      );

      clock.set(base.subtract(const Duration(days: 2)));
      await history.snapshot(
        pathA,
        utf8.encode('content A2 ${'A' * 200}'),
        reason: SnapshotReason.beforeRestore,
      );

      clock.set(base.subtract(const Duration(days: 1)));
      await history.snapshot(
        pathA,
        utf8.encode('content A3 ${'A' * 200}'),
        reason: SnapshotReason.beforeRestore,
      );

      // Path B: 2 snapshots within 2 days
      clock.set(base.subtract(const Duration(days: 2)));
      await history.snapshot(
        pathB,
        utf8.encode('content B1 ${'B' * 200}'),
        reason: SnapshotReason.beforeRestore,
      );

      clock.set(base.subtract(const Duration(days: 1)));
      await history.snapshot(
        pathB,
        utf8.encode('content B2 ${'B' * 200}'),
        reason: SnapshotReason.beforeRestore,
      );

      clock.set(base);

      expect((await history.list(pathA)).length, equals(3));
      expect((await history.list(pathB)).length, equals(2));

      // With a very small size cap (e.g. 150 bytes), all deletable snapshots
      // should be removed, but the newest snapshot of NoteA and NoteB MUST remain.
      await history.prune(maxHistoryBytes: 100);

      final remA = await history.list(pathA);
      final remB = await history.list(pathB);

      expect(remA.length, equals(1));
      expect(remB.length, equals(1));

      expect(
        utf8.decode((await history.read(remA.first))!),
        contains('content A3'),
      );
      expect(
        utf8.decode((await history.read(remB.first))!),
        contains('content B2'),
      );
    });
  });
}
