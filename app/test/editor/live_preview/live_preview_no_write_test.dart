// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/live_preview/live_preview_session.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../helpers/fake_editor_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening in Live Preview, moving caret, toggling mode 4 times causes 0 writes', () async {
    final fs = MemoryVaultFileSystem();

    final vaultDirs = [
      Directory('test_vaults/syntax'),
      Directory('../test_vaults/syntax'),
      Directory('test_vaults/edge'),
      Directory('../test_vaults/edge'),
    ];

    final notes = <(VaultPath, String)>[];
    final seenNames = <String>{};
    for (final dir in vaultDirs) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          final fileName = entity.uri.pathSegments.last;
          if (seenNames.contains(fileName)) continue;
          seenNames.add(fileName);

          final vPath = VaultPath('notes/$fileName');
          final bytes = entity.readAsBytesSync();
          final text = utf8.decode(bytes, allowMalformed: true);
          notes.add((vPath, text));
          await fs.writeText(vPath, TextDocument(text: text));
        }
      }
    }

    expect(notes.length, greaterThanOrEqualTo(20));
    final initialWrites = fs.writeCount;

    for (final (path, text) in notes) {
      final doc = NoteDocument(
        fs: fs,
        path: path,
        clock: const SystemClock(),
        parseService: const ParseService(),
      );
      await doc.load();
      final engine = FakeEditorEngine(text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
      );
      final session = LivePreviewSession(target: controller);

      // Open in Live Preview
      controller.setDecorator(session.decorator);

      // Move caret through note at intervals
      final step = (text.length / 10).clamp(1, 100).toInt();
      for (var offset = 0; offset <= text.length; offset += step) {
        controller.select(offset);
      }

      // Toggle mode 4 times
      controller.setDecorator(null); // Source
      controller.setDecorator(session.decorator); // Live Preview
      controller.setDecorator(null); // Source
      controller.setDecorator(session.decorator); // Live Preview

      session.dispose();
      controller.dispose();
    }

    // Zero additional writes
    expect(fs.writeCount, equals(initialWrites));
  });
}
