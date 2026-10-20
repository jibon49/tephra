// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import 'decision_table_test.dart';

void main() {
  group('Large-Delete Guard Thresholds', () {
    test('2 of 5 deletes does not trigger guard', () {
      final world = TestWorld();
      for (var i = 1; i <= 5; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 2) {
          world.local(path, 'h$i');
        }
      }

      final plan = world.plan();

      expect(plan.heldDeletes, isEmpty);
      final deletes = plan.actions.whereType<DeleteRemote>().toList();
      expect(deletes.length, 2);
    });

    test('3 of 10 deletes triggers guard', () {
      final world = TestWorld();
      for (var i = 1; i <= 10; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 3) {
          world.local(path, 'h$i');
        }
      }

      final plan = world.plan();

      expect(plan.actions.whereType<DeleteRemote>(), isEmpty);
      expect(plan.heldDeletes.length, 3);
      expect(plan.heldDeletes, [
        VaultPath('note_1.md'),
        VaultPath('note_2.md'),
        VaultPath('note_3.md'),
      ]);
    });

    test('50 of 10,000 deletes does not trigger guard', () {
      final world = TestWorld();
      for (var i = 1; i <= 10000; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 50) {
          world.local(path, 'h$i');
        }
      }

      final plan = world.plan();

      expect(plan.heldDeletes, isEmpty);
      expect(plan.actions.whereType<DeleteRemote>().length, 50);
    });

    test('51 of 10,000 deletes triggers guard', () {
      final world = TestWorld();
      for (var i = 1; i <= 10000; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 51) {
          world.local(path, 'h$i');
        }
      }

      final plan = world.plan();

      expect(plan.actions.whereType<DeleteRemote>(), isEmpty);
      expect(plan.heldDeletes.length, 51);
    });
  });

  group('Delete Decisions', () {
    test('approve decision keeps delete action when guard is triggered', () {
      final world = TestWorld();
      for (var i = 1; i <= 10; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 4) {
          world.local(path, 'h$i');
        }
      }

      // Approve deletion of note_1.md
      world.deleteDecisions[VaultPath('note_1.md')] = DeleteDecision.approve;

      final plan = world.plan();

      // note_1.md is approved and deleted
      final deletes = plan.actions.whereType<DeleteRemote>().toList();
      expect(deletes.length, 1);
      expect(deletes.first.path, VaultPath('note_1.md'));

      // note_2.md, note_3.md, note_4.md remain held
      expect(plan.heldDeletes, [
        VaultPath('note_2.md'),
        VaultPath('note_3.md'),
        VaultPath('note_4.md'),
      ]);
    });

    test('keep decision converts DeleteRemote to Download', () {
      final world = TestWorld();
      for (var i = 1; i <= 10; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.remotePut('devA:$i', path, 'h$i');
        if (i > 4) {
          world.local(path, 'h$i');
        }
      }

      // Keep note_1.md (missing locally)
      world.deleteDecisions[VaultPath('note_1.md')] = DeleteDecision.keep;

      final plan = world.plan();

      final downloads = plan.actions.whereType<Download>().toList();
      expect(downloads.length, 1);
      expect(downloads.first.path, VaultPath('note_1.md'));
      expect(downloads.first.expectedLocalHash, isNull);

      // note_2.md, note_3.md, note_4.md remain held
      expect(plan.heldDeletes, [
        VaultPath('note_2.md'),
        VaultPath('note_3.md'),
        VaultPath('note_4.md'),
      ]);
    });

    test('keep decision converts DeleteLocal to Upload', () {
      final world = TestWorld();
      for (var i = 1; i <= 10; i++) {
        final path = 'note_$i.md';
        world.base(path, 'h$i', 'devA:$i');
        world.local(path, 'h$i');
        if (i <= 4) {
          // Remotely deleted
          world.remoteDelete('devB:$i', path, parent: 'devA:$i');
        } else {
          world.remotePut('devA:$i', path, 'h$i');
        }
      }

      // Keep note_1.md (deleted remotely)
      world.deleteDecisions[VaultPath('note_1.md')] = DeleteDecision.keep;

      final plan = world.plan();

      final uploads = plan.actions.whereType<Upload>().toList();
      expect(uploads.length, 1);
      expect(uploads.first.path, VaultPath('note_1.md'));
      expect(uploads.first.parent, 'devB:1');

      // note_2.md, note_3.md, note_4.md remain held
      expect(plan.heldDeletes, [
        VaultPath('note_2.md'),
        VaultPath('note_3.md'),
        VaultPath('note_4.md'),
      ]);
    });
  });

  group('Determinism', () {
    test('Planning the same input twice produces identical plans', () {
      final world = TestWorld();
      world.base('a.md', 'h1', 'devA:1');
      world.local('a.md', 'h1_edit');
      world.remotePut('devA:1', 'a.md', 'h1');
      world.remotePut('devB:1', 'b.md', 'h2');

      final plan1 = world.plan();
      final plan2 = world.plan();

      expect(plan1, equals(plan2));
      expect(plan1.hashCode, equals(plan2.hashCode));
      expect(plan1.actions, equals(plan2.actions));
      expect(plan1.baseUpdates, equals(plan2.baseUpdates));
    });

    test('Shuffled map insertion order produces identical plans', () {
      final input1 = PlannerInput(
        local: {
          VaultPath('z.md'): LocalFileState(
            path: VaultPath('z.md'),
            hash: 'hz',
            size: 10,
            mtimeMs: 1,
          ),
          VaultPath('a.md'): LocalFileState(
            path: VaultPath('a.md'),
            hash: 'ha',
            size: 10,
            mtimeMs: 1,
          ),
          VaultPath('m.md'): LocalFileState(
            path: VaultPath('m.md'),
            hash: 'hm',
            size: 10,
            mtimeMs: 1,
          ),
        },
        base: {
          VaultPath('z.md'): const BaseState(
            path: 'z.md',
            caseKey: 'z.md',
            hash: 'hz_base',
            size: 10,
            mtime: 1,
            version: 'devA:1',
            blobKeys: ['b1'],
            syncedAt: 1,
          ),
          VaultPath('a.md'): const BaseState(
            path: 'a.md',
            caseKey: 'a.md',
            hash: 'ha_base',
            size: 10,
            mtime: 1,
            version: 'devA:2',
            blobKeys: ['b2'],
            syncedAt: 1,
          ),
          VaultPath('m.md'): const BaseState(
            path: 'm.md',
            caseKey: 'm.md',
            hash: 'hm_base',
            size: 10,
            mtime: 1,
            version: 'devA:3',
            blobKeys: ['b3'],
            syncedAt: 1,
          ),
        },
        remote: RemoteHistory([
          const JournalEntry(
            entryId: 'devA:1',
            deviceId: 'devA',
            seq: 1,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'z.md',
            time: 1,
          ),
          const JournalEntry(
            entryId: 'devA:2',
            deviceId: 'devA',
            seq: 2,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'a.md',
            time: 1,
          ),
          const JournalEntry(
            entryId: 'devA:3',
            deviceId: 'devA',
            seq: 3,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'm.md',
            time: 1,
          ),
        ]),
        deviceId: 'devA',
        caseInsensitive: false,
        isWindows: false,
      );

      final input2 = PlannerInput(
        local: {
          VaultPath('a.md'): LocalFileState(
            path: VaultPath('a.md'),
            hash: 'ha',
            size: 10,
            mtimeMs: 1,
          ),
          VaultPath('m.md'): LocalFileState(
            path: VaultPath('m.md'),
            hash: 'hm',
            size: 10,
            mtimeMs: 1,
          ),
          VaultPath('z.md'): LocalFileState(
            path: VaultPath('z.md'),
            hash: 'hz',
            size: 10,
            mtimeMs: 1,
          ),
        },
        base: {
          VaultPath('m.md'): const BaseState(
            path: 'm.md',
            caseKey: 'm.md',
            hash: 'hm_base',
            size: 10,
            mtime: 1,
            version: 'devA:3',
            blobKeys: ['b3'],
            syncedAt: 1,
          ),
          VaultPath('z.md'): const BaseState(
            path: 'z.md',
            caseKey: 'z.md',
            hash: 'hz_base',
            size: 10,
            mtime: 1,
            version: 'devA:1',
            blobKeys: ['b1'],
            syncedAt: 1,
          ),
          VaultPath('a.md'): const BaseState(
            path: 'a.md',
            caseKey: 'a.md',
            hash: 'ha_base',
            size: 10,
            mtime: 1,
            version: 'devA:2',
            blobKeys: ['b2'],
            syncedAt: 1,
          ),
        },
        remote: RemoteHistory([
          const JournalEntry(
            entryId: 'devA:2',
            deviceId: 'devA',
            seq: 2,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'a.md',
            time: 1,
          ),
          const JournalEntry(
            entryId: 'devA:3',
            deviceId: 'devA',
            seq: 3,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'm.md',
            time: 1,
          ),
          const JournalEntry(
            entryId: 'devA:1',
            deviceId: 'devA',
            seq: 1,
            hlc: '000000000001000.000000.devA',
            op: 'put',
            path: 'z.md',
            time: 1,
          ),
        ]),
        deviceId: 'devA',
        caseInsensitive: false,
        isWindows: false,
      );

      final plan1 = Planner.plan(input1);
      final plan2 = Planner.plan(input2);

      expect(plan1, equals(plan2));
    });
  });
}
