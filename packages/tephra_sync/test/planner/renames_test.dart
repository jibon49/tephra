// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import 'decision_table_test.dart';

void main() {
  group('Local Moves Table', () {
    test('Row 1: Remote at d is R= -> RenameRemote(d -> c)', () {
      final world = TestWorld();
      world.base('old.md', 'h1', 'devA:1');
      world.local('new.md', 'h1');
      world.remotePut('devA:1', 'old.md', 'h1');
      final plan = world.plan();

      expect(plan.actions, [
        RenameRemote(
          VaultPath('old.md'),
          to: VaultPath('new.md'),
          parent: 'devA:1',
          targetParent: null,
          hash: 'h1',
          blobKeys: ['blob_h1'],
        ),
      ]);
      expect(plan.baseUpdates, isEmpty);
    });

    test(
      'Row 2: Remote at d is RM -> Download(c, H(d)) + RenameRemote(d -> c)',
      () {
        final world = TestWorld();
        world.base('old.md', 'h1', 'devA:1');
        world.local('new.md', 'h1');
        world.remotePut('devA:1', 'old.md', 'h1', hlc: '100:0:devA');
        final h = world.remotePut(
          'devB:1',
          'old.md',
          'h2',
          parent: 'devA:1',
          hlc: '200:0:devB',
        );
        final plan = world.plan();

        expect(plan.actions, [
          Download(VaultPath('new.md'), entry: h, expectedLocalHash: 'h1'),
          RenameRemote(
            VaultPath('old.md'),
            to: VaultPath('new.md'),
            parent: 'devB:1',
            targetParent: null,
            hash: 'h2',
            blobKeys: ['blob_h2'],
          ),
        ]);
      },
    );

    test('Row 3: H(d) is move away to x with x == c -> BaseUpdates only', () {
      final world = TestWorld();
      world.base('old.md', 'h1', 'devA:1');
      world.local('new.md', 'h1');
      world.remotePut('devA:1', 'old.md', 'h1', hlc: '100:0:devA');
      final hMove = world.remoteMove(
        'devB:1',
        'old.md',
        'new.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, isEmpty);
      expect(plan.baseUpdates, [
        BaseUpdate.fromEntry(
          VaultPath('new.md'),
          hMove,
          size: 100,
          mtime: 1000,
        ),
        BaseUpdate.remove(VaultPath('old.md')),
      ]);
    });

    test('Row 4: H(d) is move away to x != c, x absent locally -> RenameLocal(c -> x)', () {
      final world = TestWorld();
      world.base('old.md', 'h1', 'devA:1');
      world.local('loc_renamed.md', 'h1');
      world.remotePut('devA:1', 'old.md', 'h1', hlc: '100:0:devA');
      world.remoteMove(
        'devB:1',
        'old.md',
        'rem_renamed.md',
        'h1',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        RenameLocal(
          VaultPath('loc_renamed.md'),
          to: VaultPath('rem_renamed.md'),
          expectedHash: 'h1',
          remoteEntryId: 'devB:1',
        ),
      ]);
    });

    test(
      'Row 5: Anything else (RD) -> do not pair; table processes both paths',
      () {
        final world = TestWorld();
        world.base('old.md', 'h1', 'devA:1');
        world.local('new.md', 'h1');
        world.remotePut('devA:1', 'old.md', 'h1', hlc: '100:0:devA');
        world.remoteDelete(
          'devB:1',
          'old.md',
          parent: 'devA:1',
          hlc: '200:0:devB',
        );
        final plan = world.plan();

        // old.md goes to BaseUpdate.remove (Row 19: LD, RD)
        // new.md goes to Upload (Row 15: LC, R0)
        expect(plan.actions, [
          Upload(VaultPath('new.md'), localHash: 'h1', parent: null),
        ]);
        expect(plan.baseUpdates, [BaseUpdate.remove(VaultPath('old.md'))]);
      },
    );
  });

  group('Remote Moves Table', () {
    test(
      'Case 1: L(f) = L= and H.hash == B(f).hash -> RenameLocal(f -> t)',
      () {
        final world = TestWorld();
        world.base('from.md', 'h1', 'devA:1');
        world.local('from.md', 'h1');
        world.remotePut('devA:1', 'from.md', 'h1', hlc: '100:0:devA');
        world.remoteMove(
          'devB:1',
          'from.md',
          'to.md',
          'h1',
          parent: 'devA:1',
          hlc: '200:0:devB',
        );
        final plan = world.plan();

        expect(plan.actions, [
          RenameLocal(
            VaultPath('from.md'),
            to: VaultPath('to.md'),
            expectedHash: 'h1',
            remoteEntryId: 'devB:1',
          ),
        ]);
      },
    );

    test(
      'Case 2: L(f) = LM and H.hash == B(f).hash -> RenameLocal + Upload(t)',
      () {
        final world = TestWorld();
        world.base('from.md', 'h1', 'devA:1');
        world.local('from.md', 'h_local_edit');
        world.remotePut('devA:1', 'from.md', 'h1', hlc: '100:0:devA');
        world.remoteMove(
          'devB:1',
          'from.md',
          'to.md',
          'h1',
          parent: 'devA:1',
          hlc: '200:0:devB',
        );
        final plan = world.plan();

        expect(plan.actions, [
          RenameLocal(
            VaultPath('from.md'),
            to: VaultPath('to.md'),
            expectedHash: 'h_local_edit',
            remoteEntryId: 'devB:1',
          ),
          Upload(
            VaultPath('to.md'),
            localHash: 'h_local_edit',
            parent: 'devB:1',
          ),
        ]);
      },
    );

    test('Case 3: L(f) = LM and H.hash != B(f).hash (mergeable) -> RenameLocal + Merge(t)', () {
      final world = TestWorld();
      world.base('from.md', 'h1', 'devA:1');
      world.local('from.md', 'h_local_edit');
      world.remotePut('devA:1', 'from.md', 'h1', hlc: '100:0:devA');
      final hMove = world.remoteMove(
        'devB:1',
        'from.md',
        'to.md',
        'h_remote_edit',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        RenameLocal(
          VaultPath('from.md'),
          to: VaultPath('to.md'),
          expectedHash: 'h_local_edit',
          remoteEntryId: 'devB:1',
        ),
        Merge(
          VaultPath('to.md'),
          kind: MergeKind.markdown,
          localHash: 'h_local_edit',
          remote: hMove,
          basePath: VaultPath('from.md'),
          baseEntryId: null,
        ),
      ]);
    });

    test('Case 4: L(f) = LM and H.hash != B(f).hash (binary) -> RenameLocal + ConflictCopy(t)', () {
      final world = TestWorld();
      world.base('from.png', 'h1', 'devA:1');
      world.local('from.png', 'h_local_edit');
      world.remotePut('devA:1', 'from.png', 'h1', hlc: '100:0:devA');
      final hMove = world.remoteMove(
        'devB:1',
        'from.png',
        'to.png',
        'h_remote_edit',
        parent: 'devA:1',
        hlc: '200:0:devB',
      );
      final plan = world.plan();

      expect(plan.actions, [
        RenameLocal(
          VaultPath('from.png'),
          to: VaultPath('to.png'),
          expectedHash: 'h_local_edit',
          remoteEntryId: 'devB:1',
        ),
        ConflictCopy(
          VaultPath('to.png'),
          localHash: 'h_local_edit',
          remote: hMove,
        ),
      ]);
    });
  });

  group('Pairing preference order', () {
    test(
      'Prefers (1) same filename in another folder over (2) same folder',
      () {
        final world = TestWorld();
        // c is folderB/item.md
        world.local('folderB/item.md', 'h_match');

        // Candidate 1: folderA/item.md (same name, other folder -> score 1)
        world.base('folderA/item.md', 'h_match', 'devA:1');
        world.remotePut('devA:1', 'folderA/item.md', 'h_match');

        // Candidate 2: folderB/old.md (same folder, different name -> score 2)
        world.base('folderB/old.md', 'h_match', 'devA:2');
        world.remotePut('devA:2', 'folderB/old.md', 'h_match');

        final plan = world.plan();

        // folderA/item.md should be paired with folderB/item.md
        final rename = plan.actions.whereType<RenameRemote>().first;
        expect(rename.path, VaultPath('folderA/item.md'));
        expect(rename.to, VaultPath('folderB/item.md'));
      },
    );

    test('Prefers (2) same folder over (3) smallest path', () {
      final world = TestWorld();
      // c is folderB/item.md
      world.local('folderB/item.md', 'h_match');

      // Candidate 2: folderB/old.md (same folder, different name -> score 2)
      world.base('folderB/old.md', 'h_match', 'devA:1');
      world.remotePut('devA:1', 'folderB/old.md', 'h_match');

      // Candidate 3: a/diff.md (lexicographically smaller, but different folder and name -> score 3)
      world.base('a/diff.md', 'h_match', 'devA:2');
      world.remotePut('devA:2', 'a/diff.md', 'h_match');

      final plan = world.plan();

      final rename = plan.actions.whereType<RenameRemote>().first;
      expect(rename.path, VaultPath('folderB/old.md'));
      expect(rename.to, VaultPath('folderB/item.md'));
    });
  });

  group('Folder rename of 30 files', () {
    test('30 file moves produce 30 RenameRemote actions', () {
      final world = TestWorld();
      for (var i = 0; i < 30; i++) {
        final idx = i.toString().padLeft(2, '0');
        final oldPath = 'folder_old/file_$idx.md';
        final newPath = 'folder_new/file_$idx.md';
        final hash = 'hash_$idx';
        final ver = 'devA:$i';

        world.base(oldPath, hash, ver);
        world.local(newPath, hash);
        world.remotePut(ver, oldPath, hash);
      }

      final plan = world.plan();

      final renames = plan.actions.whereType<RenameRemote>().toList();
      expect(renames.length, 30);
      for (var i = 0; i < 30; i++) {
        final idx = i.toString().padLeft(2, '0');
        expect(renames[i].path, VaultPath('folder_old/file_$idx.md'));
        expect(renames[i].to, VaultPath('folder_new/file_$idx.md'));
      }
    });
  });
}
