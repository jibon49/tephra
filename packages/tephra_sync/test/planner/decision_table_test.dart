// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

class TestWorld {
  TestWorld({
    this.deviceId = 'devA',
    this.caseInsensitive = false,
    this.isWindows = false,
  });

  final String deviceId;
  final bool caseInsensitive;
  final bool isWindows;

  final Map<VaultPath, LocalFileState> localMap = {};
  final Map<VaultPath, BaseState> baseMap = {};
  final List<JournalEntry> remoteEntries = [];
  final Map<VaultPath, DeleteDecision> deleteDecisions = {};

  void local(String path, String hash, {int size = 100, int mtime = 1000}) {
    localMap[VaultPath(path)] = LocalFileState(
      path: VaultPath(path),
      hash: hash,
      size: size,
      mtimeMs: mtime,
    );
  }

  void base(
    String path,
    String hash,
    String version, {
    List<String>? blobKeys,
    int size = 100,
    int mtime = 1000,
  }) {
    baseMap[VaultPath(path)] = BaseState(
      path: path,
      caseKey: path.toLowerCase(),
      hash: hash,
      size: size,
      mtime: mtime,
      version: version,
      blobKeys: blobKeys ?? ['blob_$hash'],
      syncedAt: 1000,
    );
  }

  static String formatHlc(String hlcRaw, String dev) {
    if (hlcRaw.contains('.')) return hlcRaw;
    final parts = hlcRaw.split(':');
    if (parts.length >= 2) {
      final millis = int.tryParse(parts[0]) ?? 1000;
      final counter = int.tryParse(parts[1]) ?? 0;
      final deviceId = parts.length >= 3 ? parts[2] : dev;
      return Hlc(millis: millis, counter: counter, deviceId: deviceId).encoded;
    }
    final millis = int.tryParse(hlcRaw) ?? 1000;
    return Hlc(millis: millis, counter: 0, deviceId: dev).encoded;
  }

  JournalEntry remotePut(
    String entryId,
    String path,
    String hash, {
    String? parent,
    String? mergedParent,
    String hlc = '1000:0:devB',
    List<String>? blobKeys,
    int size = 100,
    int mtime = 1000,
  }) {
    final parts = entryId.split(':');
    final dev = parts[0];
    final seq = int.parse(parts[1]);
    final entry = JournalEntry(
      entryId: entryId,
      deviceId: dev,
      seq: seq,
      hlc: formatHlc(hlc, dev),
      op: 'put',
      path: path,
      hash: hash,
      size: size,
      mtime: mtime,
      blobKeys: blobKeys ?? ['blob_$hash'],
      parent: parent,
      mergedParent: mergedParent,
      time: 1000,
    );
    remoteEntries.add(entry);
    return entry;
  }

  JournalEntry remoteDelete(
    String entryId,
    String path, {
    String? parent,
    String? mergedParent,
    String hlc = '1000:0:devB',
  }) {
    final parts = entryId.split(':');
    final dev = parts[0];
    final seq = int.parse(parts[1]);
    final entry = JournalEntry(
      entryId: entryId,
      deviceId: dev,
      seq: seq,
      hlc: formatHlc(hlc, dev),
      op: 'delete',
      path: path,
      parent: parent,
      mergedParent: mergedParent,
      time: 1000,
    );
    remoteEntries.add(entry);
    return entry;
  }

  JournalEntry remoteMove(
    String entryId,
    String fromPath,
    String toPath,
    String hash, {
    String? parent,
    String? targetParent,
    String hlc = '1000:0:devB',
    List<String>? blobKeys,
    int size = 100,
    int mtime = 1000,
  }) {
    final parts = entryId.split(':');
    final dev = parts[0];
    final seq = int.parse(parts[1]);
    final entry = JournalEntry(
      entryId: entryId,
      deviceId: dev,
      seq: seq,
      hlc: formatHlc(hlc, dev),
      op: 'move',
      path: toPath,
      fromPath: fromPath,
      hash: hash,
      size: size,
      mtime: mtime,
      blobKeys: blobKeys ?? ['blob_$hash'],
      parent: parent,
      targetParent: targetParent,
      time: 1000,
    );
    remoteEntries.add(entry);
    return entry;
  }

  SyncPlan plan() {
    final input = PlannerInput(
      local: localMap,
      base: baseMap,
      remote: RemoteHistory(remoteEntries),
      deviceId: deviceId,
      caseInsensitive: caseInsensitive,
      isWindows: isWindows,
      deleteDecisions: deleteDecisions,
    );
    return Planner.plan(input);
  }
}

void main() {
  group('Decision Table (Rows 1 to 23)', () {
    test('Row 1: L0, R0 -> none', () {
      final world = TestWorld();
      final plan = world.plan();
      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, isEmpty);
    });

    test('Row 2: L0, RC -> Download(P, H, expected: null)', () {
      final world = TestWorld();
      final h = world.remotePut('devB:1', 'note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        Download(VaultPath('note.md'), entry: h, expectedLocalHash: null),
      ]);
      expect(plan.baseUpdates, isEmpty);
    });

    test('Row 3: L=, R= -> in sync', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h1');
      world.remotePut('devA:1', 'note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, isEmpty);
    });

    test('Row 3 (newer remote version, same hash) -> BaseUpdate.set', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h1');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      world.remotePut(
        'devB:1',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [
        BaseUpdate.set(
          VaultPath('note.md'),
          'h1',
          'devB:1',
          ['blob_h1'],
          100,
          1000,
        ),
      ]);
    });

    test('Row 4: L=, RM -> Download(P, H, expected: L.hash)', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h1');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Download(VaultPath('note.md'), entry: h, expectedLocalHash: 'h1'),
      ]);
    });

    test('Row 5: L=, RD -> DeleteLocal(P)', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h1');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        DeleteLocal(
          VaultPath('note.md'),
          expectedHash: 'h1',
          remoteEntryId: 'devB:1',
        ),
      ]);
    });

    test('Row 6: L=, Rgone -> Upload(P, parent: null) + note republished', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        Upload(VaultPath('note.md'), localHash: 'h1', parent: null),
      ]);
      expect(plan.notes, [
        PlanNote(VaultPath('note.md'), PlanNoteKind.republished),
      ]);
    });

    test('Row 7: L=, RF+ (mine, mergeable with LCA) -> Merge', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.local('note.md', 'h1');
      world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Merge(
          VaultPath('note.md'),
          kind: MergeKind.markdown,
          localHash: 'h1',
          remote: h,
          basePath: VaultPath('note.md'),
          baseEntryId: 'devA:1',
          mergedParent: 'devA:2',
        ),
      ]);
    });

    test('Row 7: L=, RF+ (mine, binary) -> ConflictCopy', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('image.png', 'h1', 'devA:2');
      world.local('image.png', 'h1');
      world.remotePut('devA:1', 'image.png', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'image.png',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      final h = world.remotePut(
        'devB:1',
        'image.png',
        'h2',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        ConflictCopy(
          VaultPath('image.png'),
          localHash: 'h1',
          remote: h,
          mergedParent: 'devA:2',
        ),
      ]);
    });

    test('Row 7: L=, RF+ (mine, LCA null) -> ConflictCopy', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.local('note.md', 'h1');
      world.remotePut('devA:2', 'note.md', 'h1', hlc: '100:0:devA');
      final h = world.remotePut('devB:1', 'note.md', 'h2', hlc: '200:0:devB');
      final plan = world.plan();

      expect(plan.actions, [
        ConflictCopy(
          VaultPath('note.md'),
          localHash: 'h1',
          remote: h,
          mergedParent: 'devA:2',
        ),
      ]);
    });

    test('Row 7: L=, RF+ (not mine) -> Download', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devC:2');
      world.local('note.md', 'h1');
      world.remotePut('devC:1', 'note.md', 'h0', hlc: '100:0:devC');
      world.remotePut(
        'devC:2',
        'note.md',
        'h1',
        parent: 'devC:1',
        hlc: '200:0:devC',
      );
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devC:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Download(VaultPath('note.md'), entry: h, expectedLocalHash: 'h1'),
      ]);
    });

    test(
      'Row 8: L=, RF- (mine) -> Upload + note keptEditedFileDeletedElsewhere',
      () {
        final world = TestWorld(deviceId: 'devA');
        world.base('note.md', 'h1', 'devA:2');
        world.local('note.md', 'h1');
        world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
        world.remotePut(
          'devA:2',
          'note.md',
          'h1',
          parent: 'devA:1',
          hlc: '200:0:devA',
        );
        world.remoteDelete(
          'devB:1',
          'note.md',
          parent: 'devA:1',
          hlc: '300:0:devB',
        );
        final plan = world.plan();

        expect(plan.actions, [
          Upload(
            VaultPath('note.md'),
            localHash: 'h1',
            parent: 'devB:1',
            mergedParent: 'devA:2',
          ),
        ]);
        expect(plan.notes, [
          PlanNote(
            VaultPath('note.md'),
            PlanNoteKind.keptEditedFileDeletedElsewhere,
          ),
        ]);
      },
    );

    test('Row 8: L=, RF- (not mine) -> DeleteLocal', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devC:2');
      world.local('note.md', 'h1');
      world.remotePut('devC:1', 'note.md', 'h0', hlc: '100:0:devC');
      world.remotePut(
        'devC:2',
        'note.md',
        'h1',
        parent: 'devC:1',
        hlc: '200:0:devC',
      );
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devC:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        DeleteLocal(
          VaultPath('note.md'),
          expectedHash: 'h1',
          remoteEntryId: 'devB:1',
        ),
      ]);
    });

    test('Row 9: LM, R= -> Upload(P, parent: H.id)', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h2');
      world.remotePut('devA:1', 'note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        Upload(VaultPath('note.md'), localHash: 'h2', parent: 'devA:1'),
      ]);
    });

    test('Row 10: LM, RM (mergeable) -> Merge', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h2');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h3',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Merge(
          VaultPath('note.md'),
          kind: MergeKind.markdown,
          localHash: 'h2',
          remote: h,
          basePath: VaultPath('note.md'),
          baseEntryId: null,
        ),
      ]);
    });

    test('Row 10: LM, RM (binary) -> ConflictCopy', () {
      final world = TestWorld();
      world.base('image.png', 'h1', 'devA:1');
      world.local('image.png', 'h2');
      world.remotePut('devA:1', 'image.png', 'h1', hlc: '100:0:devA');
      final h = world.remotePut(
        'devB:1',
        'image.png',
        'h3',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        ConflictCopy(VaultPath('image.png'), localHash: 'h2', remote: h),
      ]);
    });

    test('Row 11: LM, RD -> Upload(P, parent: H.id) + note', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h2');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Upload(VaultPath('note.md'), localHash: 'h2', parent: 'devB:1'),
      ]);
      expect(plan.notes, [
        PlanNote(
          VaultPath('note.md'),
          PlanNoteKind.keptEditedFileDeletedElsewhere,
        ),
      ]);
    });

    test('Row 12: LM, Rgone -> Upload(P, parent: null) + note', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.local('note.md', 'h2');
      final plan = world.plan();

      expect(plan.actions, [
        Upload(VaultPath('note.md'), localHash: 'h2', parent: null),
      ]);
      expect(plan.notes, [
        PlanNote(VaultPath('note.md'), PlanNoteKind.republished),
      ]);
    });

    test('Row 13: LM, RF+ (mergeable) -> Merge', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.local('note.md', 'h_loc');
      world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Merge(
          VaultPath('note.md'),
          kind: MergeKind.markdown,
          localHash: 'h_loc',
          remote: h,
          basePath: VaultPath('note.md'),
          baseEntryId: 'devA:1',
          mergedParent: 'devA:2',
        ),
      ]);
    });

    test('Row 13: LM, RF+ (binary) -> ConflictCopy', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('image.png', 'h1', 'devA:2');
      world.local('image.png', 'h_loc');
      world.remotePut('devA:1', 'image.png', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'image.png',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      final h = world.remotePut(
        'devB:1',
        'image.png',
        'h2',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        ConflictCopy(
          VaultPath('image.png'),
          localHash: 'h_loc',
          remote: h,
          mergedParent: 'devA:2',
        ),
      ]);
    });

    test('Row 14: LM, RF- -> Upload + note', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.local('note.md', 'h_loc');
      world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Upload(
          VaultPath('note.md'),
          localHash: 'h_loc',
          parent: 'devB:1',
          mergedParent: 'devA:2',
        ),
      ]);
      expect(plan.notes, [
        PlanNote(
          VaultPath('note.md'),
          PlanNoteKind.keptEditedFileDeletedElsewhere,
        ),
      ]);
    });

    test('Row 15: LC, R0 -> Upload(P, parent: H?.id)', () {
      final world = TestWorld();
      world.local('note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        Upload(VaultPath('note.md'), localHash: 'h1', parent: null),
      ]);
    });

    test('Row 16: LC, RC -> ConflictCopy', () {
      final world = TestWorld();
      world.local('note.md', 'h_local');
      final h = world.remotePut('devB:1', 'note.md', 'h_remote');
      final plan = world.plan();

      expect(plan.actions, [
        ConflictCopy(VaultPath('note.md'), localHash: 'h_local', remote: h),
      ]);
    });

    test('Rule zero: LC, RC with equal hash -> BaseUpdate.set', () {
      final world = TestWorld();
      world.local('note.md', 'h_same');
      final h = world.remotePut('devB:1', 'note.md', 'h_same');
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [
        BaseUpdate.fromEntry(VaultPath('note.md'), h, size: 100, mtime: 1000),
      ]);
    });

    test('Row 17: LD, R= -> DeleteRemote', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.remotePut('devA:1', 'note.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        DeleteRemote(
          VaultPath('note.md'),
          parent: 'devA:1',
          hash: 'h1',
          blobKeys: ['blob_h1'],
        ),
      ]);
    });

    test('Row 18: LD, RM -> Download + note', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Download(VaultPath('note.md'), entry: h, expectedLocalHash: null),
      ]);
      expect(plan.notes, [
        PlanNote(
          VaultPath('note.md'),
          PlanNoteKind.restoredDeletedFileChangedElsewhere,
        ),
      ]);
    });

    test('Row 19: LD, RD -> BaseUpdate.remove', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      world.remotePut('devA:1', 'note.md', 'h1', hlc: '100:0:devA');
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [BaseUpdate.remove(VaultPath('note.md'))]);
    });

    test('Row 20: LD, Rgone -> BaseUpdate.remove', () {
      final world = TestWorld();
      world.base('note.md', 'h1', 'devA:1');
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [BaseUpdate.remove(VaultPath('note.md'))]);
    });

    test('Row 21: LD, RF+ -> Download + note', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      final h = world.remotePut(
        'devB:1',
        'note.md',
        'h2',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        Download(VaultPath('note.md'), entry: h, expectedLocalHash: null),
      ]);
      expect(plan.notes, [
        PlanNote(
          VaultPath('note.md'),
          PlanNoteKind.restoredDeletedFileChangedElsewhere,
        ),
      ]);
    });

    test('Row 22: LD, RF- -> BaseUpdate.remove', () {
      final world = TestWorld(deviceId: 'devA');
      world.base('note.md', 'h1', 'devA:2');
      world.remotePut('devA:1', 'note.md', 'h0', hlc: '100:0:devA');
      world.remotePut(
        'devA:2',
        'note.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devA',
      );
      world.remoteDelete(
        'devB:1',
        'note.md',
        parent: 'devA:1',
        hlc: '300:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [BaseUpdate.remove(VaultPath('note.md'))]);
    });

    test('Row 23: L0, (H deleted) -> none', () {
      final world = TestWorld();
      world.remoteDelete('devB:1', 'note.md');
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, isEmpty);
    });
  });
}
