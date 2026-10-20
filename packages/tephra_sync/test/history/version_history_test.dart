// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('VersionHistory', () {
    late MemoryVaultFileSystem fs;
    late ManualClock clock;
    late LocalHistory localHistory;

    setUp(() {
      fs = MemoryVaultFileSystem();
      clock = ManualClock(DateTime.utc(2026, 10, 20, 12, 0, 0));
      localHistory = LocalHistory(fs, clock);
    });

    test(
      'merges local snapshots and remote entries sorted newest first',
      () async {
        final path = VaultPath('Notes/Note.md');
        final contentLocal = utf8.encode('Local snapshot content');
        final hashLocal = contentHash(contentLocal);

        // Local snapshot at 10:00 UTC
        clock.set(DateTime.utc(2026, 10, 20, 10, 0, 0));
        await localHistory.snapshot(
          path,
          contentLocal,
          reason: SnapshotReason.beforeRestore,
        );

        // Remote entry at 11:00 UTC
        final timeRemote = DateTime.utc(
          2026,
          10,
          20,
          11,
          0,
          0,
        ).millisecondsSinceEpoch;
        final remoteEntry = JournalEntry(
          entryId: 'dev_phone:1',
          deviceId: 'dev_phone',
          seq: 1,
          hlc: Hlc(
            millis: timeRemote,
            counter: 1,
            deviceId: 'dev_phone',
          ).encoded,
          op: 'put',
          path: path.value,
          time: timeRemote,
          size: 50,
          hash: 'hash_remote_different',
          blobKeys: const ['blobs/blob1'],
        );

        final remoteHistory = RemoteHistory([remoteEntry]);
        final versionHistory = VersionHistory(
          localHistory: localHistory,
          remoteHistory: remoteHistory,
          deviceNames: const {'dev_phone': 'Pixel 8'},
        );

        final versions = await versionHistory.versions(path);
        expect(versions.length, equals(2));

        // Newest first: remote (11:00) then local (10:00)
        expect(versions[0].origin, equals(VersionOrigin.remote));
        expect(versions[0].source, equals('Pixel 8'));
        expect(versions[0].time, equals(DateTime.utc(2026, 10, 20, 11, 0, 0)));

        expect(versions[1].origin, equals(VersionOrigin.local));
        expect(versions[1].source, equals('Local snapshot'));
        expect(versions[1].hash, equals(hashLocal));
        expect(versions[1].time, equals(DateTime.utc(2026, 10, 20, 10, 0, 0)));
      },
    );

    test('de-duplicates by hash, keeping newest occurrence and listing additional sources', () async {
      final path = VaultPath('Notes/Idea.md');
      final sharedContent = utf8.encode('Shared idea text');
      final sharedHash = contentHash(sharedContent);

      // Remote entry from Pixel 8 at 10:00 UTC with sharedHash
      final timeRemote = DateTime.utc(
        2026,
        10,
        20,
        10,
        0,
        0,
      ).millisecondsSinceEpoch;
      final remoteEntry = JournalEntry(
        entryId: 'dev_phone:1',
        deviceId: 'dev_phone',
        seq: 1,
        hlc: Hlc(millis: timeRemote, counter: 1, deviceId: 'dev_phone').encoded,
        op: 'put',
        path: path.value,
        time: timeRemote,
        size: sharedContent.length,
        hash: sharedHash,
        blobKeys: const ['blobs/shared_blob'],
      );

      // Local snapshot at 11:00 UTC with identical sharedHash
      clock.set(DateTime.utc(2026, 10, 20, 11, 0, 0));
      await localHistory.snapshot(
        path,
        sharedContent,
        reason: SnapshotReason.beforeRestore,
      );

      final remoteHistory = RemoteHistory([remoteEntry]);
      final versionHistory = VersionHistory(
        localHistory: localHistory,
        remoteHistory: remoteHistory,
        deviceNames: const {'dev_phone': 'Pixel 8'},
      );

      final versions = await versionHistory.versions(path);
      // Merged and deduplicated to 1 version
      expect(versions.length, equals(1));
      final v = versions.first;

      // Newest occurrence is local snapshot (11:00)
      expect(v.origin, equals(VersionOrigin.local));
      expect(v.source, equals('Local snapshot'));
      expect(v.time, equals(DateTime.utc(2026, 10, 20, 11, 0, 0)));
      // Other source is listed
      expect(v.additionalSources, contains('Pixel 8'));
    });

    test('flags garbage-collected remote versions as unavailable', () async {
      final path = VaultPath('Notes/Note.md');
      final remoteEntry = JournalEntry(
        entryId: 'dev_phone:1',
        deviceId: 'dev_phone',
        seq: 1,
        hlc: Hlc(millis: 1000000000, counter: 1, deviceId: 'dev_phone').encoded,
        op: 'put',
        path: path.value,
        time: 1000000000,
        size: 100,
        hash: 'h1',
        blobKeys: const ['blobs/gc_collected_blob'],
      );

      final remoteHistory = RemoteHistory([remoteEntry]);
      final versionHistory = VersionHistory(
        localHistory: localHistory,
        remoteHistory: remoteHistory,
      );

      // When blobs/gc_collected_blob is NOT in availableBlobKeys
      final versionsUnavailable = await versionHistory.versions(
        path,
        availableBlobKeys: {'blobs/some_other_blob'},
      );
      expect(versionsUnavailable.length, equals(1));
      expect(versionsUnavailable.first.isAvailable, isFalse);

      // When blobs/gc_collected_blob IS in availableBlobKeys
      final versionsAvailable = await versionHistory.versions(
        path,
        availableBlobKeys: {'blobs/gc_collected_blob'},
      );
      expect(versionsAvailable.length, equals(1));
      expect(versionsAvailable.first.isAvailable, isTrue);
    });

    test('readVersion retrieves local snapshot bytes', () async {
      final path = VaultPath('Notes/Note.md');
      final content = utf8.encode('Hello local history');
      clock.set(DateTime.utc(2026, 10, 20, 12, 0, 0));
      await localHistory.snapshot(
        path,
        content,
        reason: SnapshotReason.beforeRestore,
      );

      final versionHistory = VersionHistory(
        localHistory: localHistory,
        remoteHistory: RemoteHistory(const []),
      );

      final versions = await versionHistory.versions(path);
      expect(versions.length, equals(1));

      final bytes = await versionHistory.readVersion(versions.first);
      expect(bytes, equals(content));
    });

    test('restoreVersion writes new content and snapshots current before overwrite', () async {
      final path = VaultPath('Notes/Note.md');
      final currentContent = utf8.encode('Current active note content');
      final oldContent = utf8.encode('Old version content');

      // 1. Write old snapshot
      clock.set(DateTime.utc(2026, 10, 20, 10, 0, 0));
      await localHistory.snapshot(
        path,
        oldContent,
        reason: SnapshotReason.beforeRestore,
      );

      // 2. File on disk is currentContent
      await fs.writeBytes(path, currentContent);

      final versionHistory = VersionHistory(
        localHistory: localHistory,
        remoteHistory: RemoteHistory(const []),
      );

      final versions = await versionHistory.versions(path);
      expect(versions.length, equals(1));

      // Advance clock
      clock.set(DateTime.utc(2026, 10, 20, 12, 0, 0));

      // 3. Restore old version
      await versionHistory.restoreVersion(
        version: versions.first,
        path: path,
        fs: fs,
      );

      // Current content on disk is now oldContent
      final onDisk = await fs.readBytes(path);
      expect(onDisk, equals(oldContent));

      // A new snapshot was taken for the overwritten currentContent
      final updatedSnapshots = await localHistory.list(path);
      expect(updatedSnapshots.length, equals(2));
      final newestSnapshotBytes = await localHistory.read(
        updatedSnapshots.first,
      );
      expect(newestSnapshotBytes, equals(currentContent));
    });

    test(
      'recentlyDeleted combines remote deletes and vault trash files',
      () async {
        final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

        // (a) Remote delete of Notes/RemoteDeleted.md
        final delTime = now
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch;
        final remoteEntry = JournalEntry(
          entryId: 'dev_phone:2',
          deviceId: 'dev_phone',
          seq: 2,
          hlc: Hlc(millis: delTime, counter: 1, deviceId: 'dev_phone').encoded,
          op: 'delete',
          path: 'Notes/RemoteDeleted.md',
          time: delTime,
        );

        // (b) File in vault .trash/Notes/LocalDeleted.md
        final trashPath = VaultPath('.trash/Notes/LocalDeleted.md');
        await fs.writeBytes(trashPath, utf8.encode('Local trash content'));

        final versionHistory = VersionHistory(
          localHistory: localHistory,
          remoteHistory: RemoteHistory([remoteEntry]),
          deviceNames: const {'dev_phone': 'Pixel 8'},
        );

        final deleted = await versionHistory.recentlyDeleted(fs: fs, now: now);
        expect(deleted.length, equals(2));

        final remoteDel = deleted.firstWhere(
          (d) => d.path.value == 'Notes/RemoteDeleted.md',
        );
        expect(remoteDel.source, equals(RecentlyDeletedSource.remote));
        expect(remoteDel.deletingDevice, equals('Pixel 8'));

        final localDel = deleted.firstWhere(
          (d) => d.path.value == 'Notes/LocalDeleted.md',
        );
        expect(localDel.source, equals(RecentlyDeletedSource.vaultTrash));
        expect(localDel.deletingDevice, equals('This device'));
      },
    );

    test(
      'resolveRestorePath creates collision name when path is occupied',
      () async {
        final path = VaultPath('Notes/Note.md');
        final now = DateTime.utc(2026, 10, 20, 12, 0, 0);

        // Unoccupied -> original path returned
        final path1 = await VersionHistory.resolveRestorePath(
          fs,
          path,
          now: now,
        );
        expect(path1.value, equals('Notes/Note.md'));

        // Occupied -> stem (restored YYYY-MM-DD).ext
        await fs.writeBytes(path, utf8.encode('Existing'));
        final path2 = await VersionHistory.resolveRestorePath(
          fs,
          path,
          now: now,
        );
        expect(path2.value, equals('Notes/Note (restored 2026-10-20).md'));

        // Both occupied -> stem (restored YYYY-MM-DD 1).ext
        await fs.writeBytes(path2, utf8.encode('Existing 2'));
        final path3 = await VersionHistory.resolveRestorePath(
          fs,
          path,
          now: now,
        );
        expect(path3.value, equals('Notes/Note (restored 2026-10-20 1).md'));
      },
    );

    test(
      'restoreDeletedFile restores from .trash and cleans up trash file',
      () async {
        final now = DateTime.utc(2026, 10, 20, 12, 0, 0);
        final originalPath = VaultPath('Notes/TrashMe.md');
        final trashPath = VaultPath('.trash/Notes/TrashMe.md');
        final content = utf8.encode('Recovered trash text');
        await fs.writeBytes(trashPath, content);

        final versionHistory = VersionHistory(
          localHistory: localHistory,
          remoteHistory: RemoteHistory(const []),
        );

        final deletedList = await versionHistory.recentlyDeleted(
          fs: fs,
          now: now,
        );
        expect(deletedList.length, equals(1));

        final restoredPath = await versionHistory.restoreDeletedFile(
          deleted: deletedList.first,
          fs: fs,
          now: now,
        );

        expect(restoredPath, equals(originalPath));
        expect(await fs.readBytes(restoredPath), equals(content));
        expect(await fs.stat(trashPath), isNull);
      },
    );
  });
}
