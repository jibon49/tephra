// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  test(
    'external pickup detects dart:io modifications within 1,000 ms',
    () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'tephra_pickup_test_',
      );
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final fs = IoVaultFileSystem(tempDir.path);
      final store = NoteDocumentStore(fs, const SystemClock());
      store.start();
      await fs.ready;

      final filePath = p.join(tempDir.path, 'note.md');
      File(filePath).writeAsStringSync('Initial content');

      final docPath = VaultPath('note.md');
      final doc = store.acquire(docPath);
      while (!doc.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(doc.text, 'Initial content');

      // Give watcher a moment to settle after file creation
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Measure time from dart:io write until doc.text updates
      final sw = Stopwatch()..start();
      File(filePath).writeAsStringSync('Updated external content');

      while (sw.elapsedMilliseconds < 2000) {
        if (doc.text == 'Updated external content') break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      sw.stop();

      expect(doc.text, 'Updated external content');
      // ignore: avoid_print
      print('PICKUP elapsed: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(1000));

      store.dispose();
      await fs.dispose();
    },
  );
}
