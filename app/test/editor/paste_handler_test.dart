// © 2026 Tephra. All rights reserved.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/attachment_actions.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

final class _FakeClipboard implements ClipboardImageSource {
  _FakeClipboard({this.filesList = const [], this.imageData});

  final List<String> filesList;
  final Uint8List? imageData;

  @override
  Future<List<String>> files() async => filesList;

  @override
  Future<Uint8List?> image() async => imageData;
}

void main() {
  group('handlePasteAttachment', () {
    late MemoryVaultFileSystem fs;
    late ManualClock clock;
    final fixedTime = DateTime(2026, 10, 11, 9, 30, 0);

    setUp(() {
      fs = MemoryVaultFileSystem();
      clock = ManualClock(fixedTime);
    });

    Widget buildTestHarness({
      required void Function(WidgetRef ref) onRefCaptured,
    }) {
      return testApp(
        Consumer(
          builder: (context, ref, _) {
            onRefCaptured(ref);
            return const SizedBox.shrink();
          },
        ),
        fs: fs,
      );
    }

    EditorController createController(
      WidgetRef ref,
      String initialText, {
      VaultPath? path,
    }) {
      final notePath = path ?? VaultPath('note.md');
      fs.writeText(notePath, TextDocument(text: initialText));
      final doc = NoteDocument(
        path: notePath,
        fs: fs,
        parseService: ParseService(),
        clock: clock,
      );
      doc.load();

      final engine = FakeEditorEngine(initialText);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: ParseService(),
        registry: ref.read(editorRegistryProvider),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets(
      'image available -> inserts attachment at caret as undoable edit; file stays on undo',
      (tester) async {
        late WidgetRef ref;
        await tester.pumpWidget(
          buildTestHarness(onRefCaptured: (r) => ref = r),
        );

        final controller = createController(ref, 'Hello world');
        controller.select(5); // Between "Hello" and " world"

        final pngBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x01,
        ]);
        final clipboard = _FakeClipboard(imageData: pngBytes);

        final handled = await handlePasteAttachment(
          controller,
          ref,
          clipboard: clipboard,
          isWindowsOverride: true,
        );

        expect(handled, isTrue);
        expect(
          controller.text,
          equals('Hello![[Pasted image 20261011093000.png]] world'),
        );

        final savedFile = VaultPath('Pasted image 20261011093000.png');
        expect(await fs.stat(savedFile), isNotNull);

        // Undo removes embed text
        controller.undo();
        expect(controller.text, equals('Hello world'));

        // File remains on disk
        expect(await fs.stat(savedFile), isNotNull);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('files list -> multiple embeds on separate lines', (
      tester,
    ) async {
      late WidgetRef ref;
      await tester.pumpWidget(buildTestHarness(onRefCaptured: (r) => ref = r));

      final controller = createController(ref, 'Start\nEnd');
      controller.select(6); // At \nEnd

      final tempDir = Directory.systemTemp.createTempSync('paste_test_');
      try {
        final f1 = File('${tempDir.path}/photo.png');
        final f2 = File('${tempDir.path}/doc.pdf');
        f1.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        f2.writeAsBytesSync([1, 2, 3]);

        final clipboard = _FakeClipboard(filesList: [f1.path, f2.path]);

        final handled = await handlePasteAttachment(
          controller,
          ref,
          clipboard: clipboard,
          isWindowsOverride: true,
        );

        expect(handled, isTrue);
        expect(
          controller.text,
          equals('Start\n![[photo.png]]\n![[doc.pdf]]End'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('nothing available -> returns false and does not change text', (
      tester,
    ) async {
      late WidgetRef ref;
      await tester.pumpWidget(buildTestHarness(onRefCaptured: (r) => ref = r));

      final controller = createController(ref, 'Original text');
      final clipboard = _FakeClipboard(filesList: [], imageData: null);

      final handled = await handlePasteAttachment(
        controller,
        ref,
        clipboard: clipboard,
        isWindowsOverride: true,
      );

      expect(handled, isFalse);
      expect(controller.text, equals('Original text'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('disabled on non-Windows', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(buildTestHarness(onRefCaptured: (r) => ref = r));

      final controller = createController(ref, 'Original text');
      final pngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final clipboard = _FakeClipboard(imageData: pngBytes);

      final handled = await handlePasteAttachment(
        controller,
        ref,
        clipboard: clipboard,
        isWindowsOverride: false,
      );

      expect(handled, isFalse);
      expect(controller.text, equals('Original text'));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
