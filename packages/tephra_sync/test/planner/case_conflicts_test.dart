// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import 'decision_table_test.dart';

void main() {
  group('Case Conflicts and Windows Invalid Names', () {
    test(
      'Android-made Note.md + note.md on a Windows device renames newer one',
      () {
        final world = TestWorld(
          deviceId: 'devWin',
          caseInsensitive: true,
          isWindows: true,
        );

        // Note.md was created first on Android
        world.remotePut('devAnd:1', 'Note.md', 'h1', hlc: '100:0:devAnd');

        // note.md was created second on Android
        world.remotePut('devAnd:2', 'note.md', 'h2', hlc: '200:0:devAnd');

        final plan = world.plan();

        // Note.md is kept; note.md is renamed remotely
        final renames = plan.actions.whereType<RenameRemote>().toList();
        expect(renames.length, 1);
        expect(renames.first.path, VaultPath('note.md'));
        expect(renames.first.to, VaultPath('note (case conflict).md'));

        // Note.md should be downloaded
        final downloads = plan.actions.whereType<Download>().toList();
        expect(downloads.length, 1);
        expect(downloads.first.path, VaultPath('Note.md'));

        // PlanNote for case conflict
        expect(
          plan.notes.any(
            (n) => n.kind == PlanNoteKind.renamedDueToCaseConflict,
          ),
          isTrue,
        );
      },
    );

    test('Local case-only rename is paired into RenameRemote', () {
      final world = TestWorld(
        deviceId: 'devWin',
        caseInsensitive: true,
        isWindows: true,
      );

      // Previously synced note.md
      world.base('note.md', 'h1', 'devA:1');
      // Locally renamed to Note.md with same content
      world.local('Note.md', 'h1');
      // Remote is at note.md
      world.remotePut('devA:1', 'note.md', 'h1');

      final plan = world.plan();

      final renames = plan.actions.whereType<RenameRemote>().toList();
      expect(renames.length, 1);
      expect(renames.first.path, VaultPath('note.md'));
      expect(renames.first.to, VaultPath('Note.md'));
    });

    test(
      'Invalid Windows names (a:b.md, CON.md, trailing. ) are sanitized',
      () {
        final world = TestWorld(
          deviceId: 'devWin',
          caseInsensitive: true,
          isWindows: true,
        );

        world.remotePut('devA:1', 'a:b.md', 'h1');
        world.remotePut('devA:2', 'CON.md', 'h2');
        world.remotePut('devA:3', 'trailing. ', 'h3');

        final plan = world.plan();

        final renames = plan.actions.whereType<RenameRemote>().toList();
        expect(renames.length, 3);

        final abRename = renames.firstWhere(
          (r) => r.path == VaultPath.raw('a:b.md'),
        );
        expect(abRename.to, VaultPath('a_b.md'));

        final conRename = renames.firstWhere(
          (r) => r.path == VaultPath.raw('CON.md'),
        );
        expect(conRename.to, VaultPath('CON_.md'));

        final trailingRename = renames.firstWhere(
          (r) => r.path == VaultPath.raw('trailing. '),
        );
        expect(trailingRename.to, VaultPath('trailing__'));

        expect(
          plan.notes
              .where((n) => n.kind == PlanNoteKind.sanitizedWindowsName)
              .length,
          3,
        );
      },
    );

    test('Case-sensitive device does nothing for case collisions', () {
      final world = TestWorld(
        deviceId: 'devLinux',
        caseInsensitive: false,
        isWindows: false,
      );

      world.remotePut('devA:1', 'Note.md', 'h1', hlc: '100:0:devA');
      world.remotePut('devA:2', 'note.md', 'h2', hlc: '200:0:devA');

      final plan = world.plan();

      // No renames to case conflicts
      expect(plan.actions.whereType<RenameRemote>(), isEmpty);
      // Both are downloaded normally as distinct files
      final downloads = plan.actions.whereType<Download>().toList();
      expect(downloads.length, 2);
      expect(downloads.map((d) => d.path.value).toSet(), {
        'Note.md',
        'note.md',
      });
      expect(plan.notes, isEmpty);
    });
  });
}
