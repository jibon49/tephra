// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/vault/autosave_host.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('AutosaveHost', () {
    late MemoryVaultFileSystem fs;
    late VaultPath path;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      path = VaultPath('note.md');
      await fs.writeText(path, const TextDocument(text: 'Initial'));
    });

    testWidgets(
      'lifecycle state change to inactive saves dirty docs immediately',
      (tester) async {
        late NoteDocument doc;

        await tester.pumpWidget(
          testApp(
            AutosaveHost(
              child: Consumer(
                builder: (context, ref, _) {
                  final store = ref.watch(noteDocumentStoreProvider);
                  doc = store.acquire(path);
                  return const SizedBox();
                },
              ),
            ),
            fs: fs,
          ),
        );
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 0, 'Inactive '));
        expect(doc.isDirty, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await pumpEventQueue();

        expect(doc.isDirty, isFalse);
        expect(fs.textOf('note.md'), startsWith('Inactive Initial'));
      },
    );

    testWidgets(
      'lifecycle state change to paused saves dirty docs immediately',
      (tester) async {
        late NoteDocument doc;

        await tester.pumpWidget(
          testApp(
            AutosaveHost(
              child: Consumer(
                builder: (context, ref, _) {
                  final store = ref.watch(noteDocumentStoreProvider);
                  doc = store.acquire(path);
                  return const SizedBox();
                },
              ),
            ),
            fs: fs,
          ),
        );
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 0, 'Paused '));
        expect(doc.isDirty, isTrue);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await pumpEventQueue();

        expect(doc.isDirty, isFalse);
        expect(fs.textOf('note.md'), startsWith('Paused Initial'));
      },
    );

    testWidgets(
      'lifecycle state change to hidden saves dirty docs immediately',
      (tester) async {
        late NoteDocument doc;

        await tester.pumpWidget(
          testApp(
            AutosaveHost(
              child: Consumer(
                builder: (context, ref, _) {
                  final store = ref.watch(noteDocumentStoreProvider);
                  doc = store.acquire(path);
                  return const SizedBox();
                },
              ),
            ),
            fs: fs,
          ),
        );
        await pumpEventQueue();

        doc.edit(const EditOperation(0, 0, 'Hidden '));
        expect(doc.isDirty, isTrue);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await pumpEventQueue();

        expect(doc.isDirty, isFalse);
        expect(fs.textOf('note.md'), startsWith('Hidden Initial'));
      },
    );
  });
}
