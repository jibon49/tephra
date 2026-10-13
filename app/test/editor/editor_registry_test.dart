// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';

void main() {
  group('EditorRegistry', () {
    late MemoryVaultFileSystem fs;
    late NoteDocumentStore store;
    late EditorRegistry registry;

    setUp(() {
      fs = MemoryVaultFileSystem();
      store = NoteDocumentStore(fs, const SystemClock());
      registry = EditorRegistry();
    });

    test(
      'register/unregister notify listeners and track controllers',
      () async {
        final path = VaultPath('note.md');
        await fs.writeText(path, const TextDocument(text: 'Hello'));
        final doc = store.acquire(path);
        await doc.load();

        final engine = FakeEditorEngine(doc.text);
        var notifications = 0;
        registry.addListener(() => notifications++);

        final controller = EditorController(
          document: doc,
          engine: engine,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: registry,
        );

        // EditorController auto-registers in registry on construction
        expect(notifications, equals(1));
        expect(registry.controllerFor(path), equals(controller));
        expect(registry.all, contains(controller));

        controller.dispose();
        // unregister on dispose
        expect(notifications, equals(2));
        expect(registry.controllerFor(path), isNull);
        expect(registry.all, isEmpty);
      },
    );

    test(
      'controllerFor follows a path change after store.retargetPath',
      () async {
        final oldPath = VaultPath('Folder/note.md');
        final newPath = VaultPath('Folder/renamed.md');
        await fs.writeText(oldPath, const TextDocument(text: 'Hello'));
        final doc = store.acquire(oldPath);
        await doc.load();

        final engine = FakeEditorEngine(doc.text);
        final controller = EditorController(
          document: doc,
          engine: engine,
          options: const EditorOptions(),
          parseService: const ParseService(),
          registry: registry,
        );

        expect(registry.controllerFor(oldPath), equals(controller));
        expect(registry.controllerFor(newPath), isNull);

        // Retarget path in doc store
        store.retargetPath(oldPath, newPath);

        // Document path has updated
        expect(doc.path, equals(newPath));
        // Controller follows doc.path
        expect(controller.path, equals(newPath));
        expect(registry.controllerFor(newPath), equals(controller));
        expect(registry.controllerFor(oldPath), isNull);

        controller.dispose();
      },
    );
  });
}
