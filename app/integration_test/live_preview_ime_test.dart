// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/live_preview/live_preview_session.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../test/helpers/fake_editor_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'IME composing inside **bo|ld** freezes reveal and avoids duplicated text',
    (tester) async {
      final fs = MemoryVaultFileSystem();
      const initialText = 'Prefix **bold** suffix';
      await fs.writeText(
        VaultPath('Test.md'),
        const TextDocument(text: initialText),
      );
      final doc = NoteDocument(
        fs: fs,
        path: VaultPath('Test.md'),
        clock: const SystemClock(),
        parseService: const ParseService(),
      );
      await doc.load();
      final engine = FakeEditorEngine(initialText);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
      );
      final session = LivePreviewSession(target: controller);
      controller.setDecorator(session.decorator);

      // Caret inside **bo|ld**: offset 11
      controller.select(11);
      expect(controller.selection.baseOffset, equals(11));

      // Active range before IME
      final activeBefore = session.active;
      expect(activeBefore.start, equals(11));
      expect(activeBefore.end, equals(11));

      // Start IME composing: e.g. typing Bangla or Japanese text
      // Simulate composing range [11, 15)
      engine.composing = const TextRange(start: 11, end: 15);
      engine.replaceRange(11, 11, 'bang');

      // The active range is frozen covering composing
      expect(session.active.start, lessThanOrEqualTo(11));
      expect(session.active.end, greaterThanOrEqualTo(15));

      // Move cursor while composing (simulate IME replacement)
      engine.replaceRange(11, 15, 'বাংলা');
      engine.composing = const TextRange(start: 11, end: 16);

      // Finish composing
      engine.composing = TextRange.empty;
      expect(controller.text, contains('**boবাংলাld**'));

      session.dispose();
      controller.dispose();
    },
  );
}
