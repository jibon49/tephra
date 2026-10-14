// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/attachment_actions.dart';
import 'package:tephra/editor/attachment_service.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';
import '../helpers/test_app.dart';

final class _HugeByteList extends ListBase<int> {
  @override
  int get length => AttachmentService.maxBytes + 1;

  @override
  set length(int newLength) => throw UnsupportedError('read-only');

  @override
  int operator [](int index) => 0;

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read-only');
}

void main() {
  group('attachment_actions', () {
    late MemoryVaultFileSystem fs;
    late ManualClock clock;
    final fixedTime = DateTime(2026, 10, 11, 9, 30, 0);

    setUp(() {
      fs = MemoryVaultFileSystem();
      clock = ManualClock(fixedTime);
    });

    Widget buildTestHarness({
      required void Function(BuildContext context, WidgetRef ref) onCaptured,
    }) {
      return testApp(
        Consumer(
          builder: (context, ref, _) {
            onCaptured(context, ref);
            return const Scaffold(body: SizedBox.expand());
          },
        ),
        fs: fs,
        overrides: [
          activeNotePathProvider.overrideWithValue(VaultPath('note.md')),
        ],
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

    testWidgets('inserting replaces non-empty selection', (tester) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        buildTestHarness(
          onCaptured: (c, r) {
            capturedContext = c;
            capturedRef = r;
          },
        ),
      );

      final controller = createController(capturedRef, 'Hello beautiful world');
      controller.select(6, 15); // Select "beautiful"

      await insertAttachmentsInto(controller, capturedRef, [
        const AttachmentInput(bytes: [1, 2, 3], fileName: 'doc.pdf'),
      ], context: capturedContext);

      expect(controller.text, equals('Hello ![[doc.pdf]] world'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('two inputs inserted on two lines', (tester) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        buildTestHarness(
          onCaptured: (c, r) {
            capturedContext = c;
            capturedRef = r;
          },
        ),
      );

      final controller = createController(capturedRef, 'Note: ');
      controller.select(6);

      await insertAttachmentsInto(controller, capturedRef, [
        const AttachmentInput(
          bytes: [1, 2],
          fileName: 'first.png',
          isImage: true,
        ),
        const AttachmentInput(
          bytes: [3, 4],
          fileName: 'second.png',
          isImage: true,
        ),
      ], context: capturedContext);

      expect(controller.text, equals('Note: ![[first.png]]\n![[second.png]]'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      'failing input reports error in snackbar and successful ones are still inserted',
      (tester) async {
        late BuildContext capturedContext;
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          buildTestHarness(
            onCaptured: (c, r) {
              capturedContext = c;
              capturedRef = r;
            },
          ),
        );

        final controller = createController(capturedRef, '');

        await insertAttachmentsInto(controller, capturedRef, [
          AttachmentInput(bytes: _HugeByteList(), fileName: 'huge.bin'),
          const AttachmentInput(bytes: [1, 2, 3], fileName: 'valid.pdf'),
        ], context: capturedContext);
        await tester.pump();

        expect(controller.text, equals('![[valid.pdf]]'));
        expect(find.byType(SnackBar), findsOneWidget);
        final l10n = AppLocalizations.of(capturedContext);
        expect(find.text(l10n.attachmentTooLarge), findsOneWidget);

        await tester.pump(
          const Duration(seconds: 5),
        ); // Allow snackbar and timers to complete
      },
    );

    testWidgets('Android sheet shows three 56 dp rows', (tester) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        buildTestHarness(
          onCaptured: (c, r) {
            capturedContext = c;
            capturedRef = r;
          },
        ),
      );

      final controller = createController(capturedRef, 'Testing');

      // Trigger pickAndInsertAttachment asynchronously
      unawaited(
        pickAndInsertAttachment(
          capturedContext,
          capturedRef,
          isAndroidOverride: true,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(capturedContext);
      expect(find.text(l10n.attachmentPickPhoto), findsOneWidget);
      expect(find.text(l10n.attachmentTakePhoto), findsOneWidget);
      expect(find.text(l10n.attachmentPickFile), findsOneWidget);

      final photoBox = find.ancestor(
        of: find.text(l10n.attachmentPickPhoto),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(photoBox.first).height, equals(56.0));

      final cameraBox = find.ancestor(
        of: find.text(l10n.attachmentTakePhoto),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(cameraBox.first).height, equals(56.0));

      final fileBox = find.ancestor(
        of: find.text(l10n.attachmentPickFile),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(fileBox.first).height, equals(56.0));

      // Dismiss (cancel)
      await tester.tapAt(const Offset(10, 10)); // Tap barrier
      await tester.pumpAndSettle();

      expect(controller.text, equals('Testing'));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
