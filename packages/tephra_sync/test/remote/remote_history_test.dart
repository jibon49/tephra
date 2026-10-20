// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('RemoteHistory', () {
    test('linear chain: head is the last entry and has 1 leaf', () {
      final entries = [
        const JournalEntry(
          entryId: 'dev1:1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'dev1:2',
          deviceId: 'dev1',
          seq: 2,
          hlc: '000000000002000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:1',
          time: 2000,
        ),
        const JournalEntry(
          entryId: 'dev1:3',
          deviceId: 'dev1',
          seq: 3,
          hlc: '000000000003000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:2',
          time: 3000,
        ),
      ];

      final history = RemoteHistory(entries);
      expect(history.leaves('Note.md').length, equals(1));
      expect(history.head('Note.md')?.entryId, equals('dev1:3'));
      expect(history.isForked('Note.md'), isFalse);
      expect(history.livePaths(), contains('Note.md'));
    });

    test(
      'fork: two puts with same parent -> two leaves, head = higher HLC',
      () {
        final entries = [
          const JournalEntry(
            entryId: 'dev1:1',
            deviceId: 'dev1',
            seq: 1,
            hlc: '000000000001000.000000.dev1',
            op: 'put',
            path: 'Note.md',
            time: 1000,
          ),
          // Fork branch A
          const JournalEntry(
            entryId: 'dev1:2',
            deviceId: 'dev1',
            seq: 2,
            hlc: '000000000002000.000000.dev1',
            op: 'put',
            path: 'Note.md',
            parent: 'dev1:1',
            time: 2000,
          ),
          // Fork branch B (concurrent on another device with higher HLC)
          const JournalEntry(
            entryId: 'dev2:1',
            deviceId: 'dev2',
            seq: 1,
            hlc: '000000000002500.000000.dev2',
            op: 'put',
            path: 'Note.md',
            parent: 'dev1:1',
            time: 2500,
          ),
        ];

        final history = RemoteHistory(entries);
        expect(history.isForked('Note.md'), isTrue);

        final leaves = history.leaves('Note.md');
        expect(leaves.length, equals(2));
        expect(leaves.map((e) => e.entryId), containsAll(['dev1:2', 'dev2:1']));

        // Head is branch B (higher HLC 2500 vs 2000)
        expect(history.head('Note.md')?.entryId, equals('dev2:1'));
      },
    );

    test('merge entry with mergedParent resolves fork to one leaf', () {
      final entries = [
        const JournalEntry(
          entryId: 'dev1:1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'dev1:2',
          deviceId: 'dev1',
          seq: 2,
          hlc: '000000000002000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:1',
          time: 2000,
        ),
        const JournalEntry(
          entryId: 'dev2:1',
          deviceId: 'dev2',
          seq: 1,
          hlc: '000000000002500.000000.dev2',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:1',
          time: 2500,
        ),
        // Merge entry referencing both leaves
        const JournalEntry(
          entryId: 'dev1:3',
          deviceId: 'dev1',
          seq: 3,
          hlc: '000000000003000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:2',
          mergedParent: 'dev2:1',
          time: 3000,
        ),
      ];

      final history = RemoteHistory(entries);
      expect(history.isForked('Note.md'), isFalse);
      expect(history.leaves('Note.md').length, equals(1));
      expect(history.head('Note.md')?.entryId, equals('dev1:3'));
    });

    test('move chain across paths', () {
      final entries = [
        // Created at A.md
        const JournalEntry(
          entryId: 'dev1:1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'A.md',
          time: 1000,
        ),
        // Moved A.md -> B.md
        const JournalEntry(
          entryId: 'dev1:2',
          deviceId: 'dev1',
          seq: 2,
          hlc: '000000000002000.000000.dev1',
          op: 'move',
          path: 'B.md',
          fromPath: 'A.md',
          parent: 'dev1:1',
          targetParent: null,
          time: 2000,
        ),
      ];

      final history = RemoteHistory(entries);

      // A.md is deleted (moved away)
      expect(history.head('A.md')?.entryId, equals('dev1:2'));
      expect(RemoteHistory.isPresentAt(history.head('A.md')!, 'A.md'), isFalse);
      expect(history.livePaths(), isNot(contains('A.md')));

      // B.md is present
      expect(history.head('B.md')?.entryId, equals('dev1:2'));
      expect(RemoteHistory.isPresentAt(history.head('B.md')!, 'B.md'), isTrue);
      expect(history.livePaths(), contains('B.md'));
    });

    test('delete then re-create at same path', () {
      final entries = [
        const JournalEntry(
          entryId: 'dev1:1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'dev1:2',
          deviceId: 'dev1',
          seq: 2,
          hlc: '000000000002000.000000.dev1',
          op: 'delete',
          path: 'Note.md',
          parent: 'dev1:1',
          time: 2000,
        ),
        const JournalEntry(
          entryId: 'dev1:3',
          deviceId: 'dev1',
          seq: 3,
          hlc: '000000000003000.000000.dev1',
          op: 'put',
          path: 'Note.md',
          parent: 'dev1:2',
          time: 3000,
        ),
      ];

      final history = RemoteHistory(entries);
      expect(history.leaves('Note.md').length, equals(1));
      expect(history.head('Note.md')?.entryId, equals('dev1:3'));
      expect(history.livePaths(), contains('Note.md'));
    });

    test('lowest common ancestor on a diamond fork and merge', () {
      // Root: 1 -> A: 2a, B: 2b -> Merge: 3 (merging 2a and 2b)
      final entries = [
        const JournalEntry(
          entryId: 'root',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'Doc.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'branchA',
          deviceId: 'dev1',
          seq: 2,
          hlc: '000000000002000.000000.dev1',
          op: 'put',
          path: 'Doc.md',
          parent: 'root',
          time: 2000,
        ),
        const JournalEntry(
          entryId: 'branchB',
          deviceId: 'dev2',
          seq: 1,
          hlc: '000000000002100.000000.dev2',
          op: 'put',
          path: 'Doc.md',
          parent: 'root',
          time: 2100,
        ),
      ];

      final history = RemoteHistory(entries);
      final lca = history.lowestCommonAncestor('branchA', 'branchB', 'Doc.md');
      expect(lca?.entryId, equals('root'));

      expect(history.isAncestorOrEqual('root', 'branchA', 'Doc.md'), isTrue);
      expect(history.isAncestorOrEqual('root', 'branchB', 'Doc.md'), isTrue);
      expect(
        history.isAncestorOrEqual('branchA', 'branchB', 'Doc.md'),
        isFalse,
      );
    });

    test('unknown parent ids do not throw and gracefully end walk', () {
      final entries = [
        const JournalEntry(
          entryId: 'dev1:10',
          deviceId: 'dev1',
          seq: 10,
          hlc: '000000000010000.000000.dev1',
          op: 'put',
          path: 'Doc.md',
          parent: 'non-existent-parent',
          time: 10000,
        ),
      ];

      final history = RemoteHistory(entries);
      expect(
        history.isAncestorOrEqual('some-id', 'dev1:10', 'Doc.md'),
        isFalse,
      );
      expect(
        history.lowestCommonAncestor('dev1:10', 'non-existent-id', 'Doc.md'),
        isNull,
      );
    });

    test('versions returns all entries in descending HLC order', () {
      final entries = [
        const JournalEntry(
          entryId: 'e1',
          deviceId: 'dev1',
          seq: 1,
          hlc: '000000000001000.000000.dev1',
          op: 'put',
          path: 'Doc.md',
          time: 1000,
        ),
        const JournalEntry(
          entryId: 'e3',
          deviceId: 'dev1',
          seq: 3,
          hlc: '000000000003000.000000.dev1',
          op: 'put',
          path: 'Doc.md',
          time: 3000,
        ),
        const JournalEntry(
          entryId: 'e2',
          deviceId: 'dev2',
          seq: 1,
          hlc: '000000000002000.000000.dev2',
          op: 'put',
          path: 'Doc.md',
          time: 2000,
        ),
      ];

      final history = RemoteHistory(entries);
      final versions = history.versions('Doc.md');
      expect(versions.map((e) => e.entryId), equals(['e3', 'e2', 'e1']));
    });
  });
}
