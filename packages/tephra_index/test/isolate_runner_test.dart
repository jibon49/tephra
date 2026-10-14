// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateIndexRunner with IoVaultFileSystem', () {
    late Directory tempDir;
    late String dbFile;
    late IoVaultFileSystem fs;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tephra_isolate_test_');
      dbFile = p.join(tempDir.path, '.tephra', 'index.db');
      fs = IoVaultFileSystem(tempDir.path);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('reconcile, incremental change, reopen and clean close', () async {
      // 1. Create A.md and B.md on disk
      File(p.join(tempDir.path, 'A.md')).writeAsStringSync('[[B]]\n# Note A');
      File(p.join(tempDir.path, 'B.md')).writeAsStringSync('# Note B');

      // 2. Open NoteIndex (spawns worker isolate)
      final index = await NoteIndex.open(dbFile, fs);
      await index.reconcile();

      // 3. Verify backlinks
      final backlinksToB = await index.backlinks(VaultPath('B.md'));
      expect(backlinksToB.length, 1);
      expect(backlinksToB.first.source, VaultPath('A.md'));

      // 4. Write C.md and send onChange(FileCreated)
      File(p.join(tempDir.path, 'C.md')).writeAsStringSync('# Note C');
      await index.onChange(FileCreated(VaultPath('C.md')));

      final notesAfterC = await index.allNotes();
      expect(notesAfterC.length, 3);
      expect(
        notesAfterC.map((n) => n.path),
        containsAll([VaultPath('A.md'), VaultPath('B.md'), VaultPath('C.md')]),
      );

      // 5. Close cleanly (within 5 seconds)
      final closeFuture = index.close();
      await expectLater(
        closeFuture.timeout(const Duration(seconds: 5)),
        completes,
      );

      // 6. Reopen same DB file without reconcile
      final index2 = await NoteIndex.open(dbFile, fs);
      final notesReopened = await index2.allNotes();
      expect(notesReopened.length, 3);

      final close2Future = index2.close();
      await expectLater(
        close2Future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });
  });
}
