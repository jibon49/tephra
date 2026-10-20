// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  late MemoryVaultFileSystem fs;
  late SyncStateStore store;
  late LocalHistory localHistory;
  late ConflictResolver resolver;
  final testClock = ManualClock(DateTime.utc(2026, 10, 20, 12, 0, 0));

  setUp(() async {
    fs = MemoryVaultFileSystem();
    store = await SyncStateStore.openMemory();
    localHistory = LocalHistory(fs, testClock);
    resolver = ConflictResolver(
      fs: fs,
      store: store,
      localHistory: localHistory,
      clock: testClock,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('ConflictResolver', () {
    test(
      'keepMine overwrites main path, moves copy to trash, snapshots both',
      () async {
        final mainPath = VaultPath('Notes/Ideas.md');
        final copyPath = VaultPath(
          'Notes/Ideas (conflict device 2026-10-20).md',
        );

        await fs.writeText(mainPath, const TextDocument(text: 'Their version'));
        await fs.writeText(copyPath, const TextDocument(text: 'My version'));

        final conflictId = await store.addConflict(
          ConflictRecord(
            time: testClock.now().millisecondsSinceEpoch,
            path: mainPath.value,
            copyPath: copyPath.value,
            kind: 'content',
            otherDevice: 'Device-B',
          ),
        );

        await resolver.resolve(
          conflictId: conflictId,
          resolution: ConflictResolution.keepMine,
        );

        // Main file content updated to copy's content
        final mainContent = await fs.readText(mainPath);
        expect(mainContent.text, 'My version');

        // Copy file moved to vault trash
        expect(await fs.stat(copyPath), isNull);
        final trashEntry = await fs.stat(VaultPath('.trash/${copyPath.value}'));
        expect(trashEntry, isNotNull);

        // Snapshots created for both files
        final mainSnapshots = await localHistory.list(mainPath);
        expect(mainSnapshots, isNotEmpty);
        final copySnapshots = await localHistory.list(copyPath);
        expect(copySnapshots, isNotEmpty);

        // Conflict marked resolved
        final conflicts = await store.conflicts();
        expect(conflicts.first.resolved, isTrue);

        // Log entry recorded
        final logs = await store.log();
        expect(
          logs.any(
            (l) =>
                l.kind == 'conflictResolved' && l.detail!.contains('kept mine'),
          ),
          isTrue,
        );
      },
    );

    test(
      'keepTheirs keeps main path, moves copy to trash, snapshots copy',
      () async {
        final mainPath = VaultPath('Docs/Spec.md');
        final copyPath = VaultPath('Docs/Spec (conflict device 2026-10-20).md');

        await fs.writeText(
          mainPath,
          const TextDocument(text: 'Their winning spec'),
        );
        await fs.writeText(
          copyPath,
          const TextDocument(text: 'My local draft'),
        );

        final conflictId = await store.addConflict(
          ConflictRecord(
            time: testClock.now().millisecondsSinceEpoch,
            path: mainPath.value,
            copyPath: copyPath.value,
            kind: 'content',
            otherDevice: 'Laptop-X',
          ),
        );

        await resolver.resolve(
          conflictId: conflictId,
          resolution: ConflictResolution.keepTheirs,
        );

        // Main file content unchanged
        final mainContent = await fs.readText(mainPath);
        expect(mainContent.text, 'Their winning spec');

        // Copy file moved to vault trash
        expect(await fs.stat(copyPath), isNull);
        expect(await fs.stat(VaultPath('.trash/${copyPath.value}')), isNotNull);

        // Snapshot created for copy
        final copySnapshots = await localHistory.list(copyPath);
        expect(copySnapshots, isNotEmpty);

        // Conflict marked resolved
        final conflicts = await store.conflicts();
        expect(conflicts.first.resolved, isTrue);

        // Log entry recorded
        final logs = await store.log();
        expect(
          logs.any(
            (l) =>
                l.kind == 'conflictResolved' &&
                l.detail!.contains('kept theirs'),
          ),
          isTrue,
        );
      },
    );

    test(
      'keepBoth leaves both files untouched on disk and marks resolved',
      () async {
        final mainPath = VaultPath('Photo.png');
        final copyPath = VaultPath('Photo (conflict device 2026-10-20).png');

        await fs.writeBytes(mainPath, utf8.encode('remote image bytes'));
        await fs.writeBytes(copyPath, utf8.encode('local image bytes'));

        final conflictId = await store.addConflict(
          ConflictRecord(
            time: testClock.now().millisecondsSinceEpoch,
            path: mainPath.value,
            copyPath: copyPath.value,
            kind: 'binary',
            otherDevice: 'Pixel-9',
          ),
        );

        await resolver.resolve(
          conflictId: conflictId,
          resolution: ConflictResolution.keepBoth,
        );

        // Both files remain
        expect(await fs.stat(mainPath), isNotNull);
        expect(await fs.stat(copyPath), isNotNull);

        // Conflict marked resolved
        final conflicts = await store.conflicts();
        expect(conflicts.first.resolved, isTrue);

        // Log entry recorded
        final logs = await store.log();
        expect(
          logs.any(
            (l) =>
                l.kind == 'conflictResolved' && l.detail!.contains('kept both'),
          ),
          isTrue,
        );
      },
    );

    test(
      'editMerge writes custom merged text, trashes copy, snapshots both',
      () async {
        final mainPath = VaultPath('Merged.md');
        final copyPath = VaultPath('Merged (conflict copy).md');

        await fs.writeText(
          mainPath,
          const TextDocument(text: 'Section A\nSection B\n'),
        );
        await fs.writeText(
          copyPath,
          const TextDocument(text: 'Section A\nSection C\n'),
        );

        final conflictId = await store.addConflict(
          ConflictRecord(
            time: testClock.now().millisecondsSinceEpoch,
            path: mainPath.value,
            copyPath: copyPath.value,
            kind: 'content',
            otherDevice: 'Desktop-Work',
          ),
        );

        await resolver.resolve(
          conflictId: conflictId,
          resolution: ConflictResolution.editMerge,
          mergedText: 'Section A\nSection B\nSection C\n',
        );

        // Main file content updated to merged text
        final mainContent = await fs.readText(mainPath);
        expect(mainContent.text, 'Section A\nSection B\nSection C\n');

        // Copy file moved to vault trash
        expect(await fs.stat(copyPath), isNull);
        expect(await fs.stat(VaultPath('.trash/${copyPath.value}')), isNotNull);

        // Snapshots created for both files
        expect(await localHistory.list(mainPath), isNotEmpty);
        expect(await localHistory.list(copyPath), isNotEmpty);

        // Conflict marked resolved
        final conflicts = await store.conflicts();
        expect(conflicts.first.resolved, isTrue);

        // Log entry recorded
        final logs = await store.log();
        expect(
          logs.any(
            (l) =>
                l.kind == 'conflictResolved' &&
                l.detail!.contains('edited merge'),
          ),
          isTrue,
        );
      },
    );

    test(
      'autoResolveDisappeared marks resolved when copy is deleted outside',
      () async {
        final mainPath = VaultPath('Project/Task.md');
        final copyPath = VaultPath(
          'Project/Task (conflict device 2026-10-20).md',
        );

        await fs.writeText(mainPath, const TextDocument(text: 'Current task'));
        await fs.writeText(copyPath, const TextDocument(text: 'Conflict copy'));

        await store.addConflict(
          ConflictRecord(
            time: testClock.now().millisecondsSinceEpoch,
            path: mainPath.value,
            copyPath: copyPath.value,
            kind: 'content',
            otherDevice: 'Device-B',
          ),
        );

        // While file exists, autoResolveDisappeared does nothing
        var resolvedCount = await resolver.autoResolveDisappeared();
        expect(resolvedCount, 0);
        expect((await store.conflicts()).first.resolved, isFalse);

        // User deletes copy in explorer
        await fs.delete(copyPath, mode: TrashMode.permanent);

        // Now autoResolveDisappeared marks it resolved
        resolvedCount = await resolver.autoResolveDisappeared();
        expect(resolvedCount, 1);
        final updated = await store.conflicts();
        expect(updated.first.resolved, isTrue);

        // Log entry recorded
        final logs = await store.log();
        expect(
          logs.any(
            (l) => l.kind == 'conflictResolved' && l.detail!.contains('auto'),
          ),
          isTrue,
        );
      },
    );
  });
}
