// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/quick_switcher_items.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../helpers/fake_editor_engine.dart';

class _FakeNoteIndexNotifier extends NoteIndexNotifier {
  _FakeNoteIndexNotifier(this.index);
  final NoteIndex index;

  @override
  Future<NoteIndex> build() async => index;
}

class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

class _ControllableNoteIndexNotifier extends NoteIndexNotifier {
  _ControllableNoteIndexNotifier(this.completers);
  final List<Completer<NoteIndex>> completers;
  var _callCount = 0;

  @override
  Future<NoteIndex> build() {
    final c = completers[_callCount++];
    return c.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutocompleteController', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late EditorRegistry registry;
    late NoteDocumentStore store;
    late VaultSession session;
    late ProviderContainer container;
    late VaultPath path;
    late NoteDocument doc;
    late FakeEditorEngine engine;
    late EditorController editor;
    late AutocompleteController autoController;

    setUp(() async {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      index = await NoteIndex.open(':memory:', fs);
      registry = EditorRegistry();
      store = NoteDocumentStore(fs, const SystemClock());
      path = VaultPath('Doc.md');

      await fs.writeText(path, const TextDocument(text: 'Hello '));
      await fs.writeText(
        VaultPath('Alpha.md'),
        const TextDocument(text: '# Alpha\n## Beta Heading\n'),
      );
      await fs.writeText(
        VaultPath('Beta.md'),
        const TextDocument(text: '# Beta\n'),
      );
      await fs.writeText(
        VaultPath('Gamma.md'),
        const TextDocument(text: '# Gamma\n'),
      );
      await index.reconcile();

      session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
      );

      final switcherItems = [
        SwitcherItem(path: VaultPath('Alpha.md'), primary: 'Alpha'),
        SwitcherItem(path: VaultPath('Beta.md'), primary: 'Beta'),
        SwitcherItem(path: VaultPath('Gamma.md'), primary: 'Gamma'),
      ];

      container = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          editorRegistryProvider.overrideWithValue(registry),
          noteDocumentStoreProvider.overrideWithValue(store),
          switcherItemsProvider.overrideWith((ref) => switcherItems),
        ],
      );

      doc = store.acquire(path);
      await doc.load();

      engine = FakeEditorEngine(doc.text);
      editor = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      autoController = container.read(
        autocompleteControllerProvider('tab1').notifier,
      );
      autoController.attach(editor);
    });

    tearDown(() async {
      autoController.detach();
      editor.dispose();
      store.release(path);
      container.dispose();
      await index.close();
    });

    test('typing [[ after Hello shows the popup with items', () async {
      expect(autoController.state.visible, isFalse);

      // Caret at end of 'Hello ' (offset 6), insert '[['
      editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
      await Future<void>.delayed(Duration.zero);

      expect(editor.text, equals('Hello [['));
      expect(editor.selection.baseOffset, equals(8));

      expect(autoController.state.visible, isTrue);
      expect(autoController.state.items.length, equals(3));
      expect(autoController.state.items.map((i) => i.primary).toList(), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
    });

    test('Esc hides and typing another character in the same context keeps it hidden', () async {
      editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
      await Future<void>.delayed(Duration.zero);
      expect(autoController.state.visible, isTrue);

      // Send Escape
      final escResult = editor.focusNode.onKeyEvent!(
        editor.focusNode,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
      );
      expect(escResult, equals(KeyEventResult.handled));
      expect(autoController.state.visible, isFalse);

      // Typing another character 'a' in same context keeps it hidden
      editor.apply(const EditOperation(8, 8, 'a'), selectAfter: true);
      await Future<void>.delayed(Duration.zero);
      expect(editor.text, equals('Hello [[a'));
      expect(autoController.state.visible, isFalse);
    });

    test('moving the caret out hides', () async {
      editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
      await Future<void>.delayed(Duration.zero);
      expect(autoController.state.visible, isTrue);

      // Move caret to start of document
      editor.select(0);
      await Future<void>.delayed(Duration.zero);
      expect(autoController.state.visible, isFalse);
    });

    test(
      'Down x2 + Enter accepts the third item as ONE applyEdits call',
      () async {
        editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
        await Future<void>.delayed(Duration.zero);
        expect(autoController.state.visible, isTrue);
        expect(autoController.state.selected, equals(0));

        // Down 1
        editor.focusNode.onKeyEvent!(
          editor.focusNode,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowDown,
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        );
        expect(autoController.state.selected, equals(1));

        // Down 2
        editor.focusNode.onKeyEvent!(
          editor.focusNode,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowDown,
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        );
        expect(autoController.state.selected, equals(2));
        expect(autoController.state.items[2].primary, equals('Gamma'));

        // Count applyEdits / edits stream events
        var editEvents = 0;
        final sub = editor.edits.listen((_) => editEvents++);

        // Enter
        final enterResult = editor.focusNode.onKeyEvent!(
          editor.focusNode,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.enter,
            logicalKey: LogicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );
        expect(enterResult, equals(KeyEventResult.handled));

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        // Accepted Gamma as one edit
        expect(editEvents, equals(1));
        expect(editor.text, equals('Hello [[Gamma]]'));
        expect(autoController.state.visible, isFalse);
      },
    );

    test('composing non-empty -> no popup and no key interception', () async {
      // Set non-empty IME composing range
      engine.composing = const TextRange(start: 6, end: 8);

      editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
      await Future<void>.delayed(Duration.zero);

      expect(autoController.state.visible, isFalse);
      expect(editor.focusNode.onKeyEvent, isNull);
    });

    test('Ctrl+Space forces the popup in an empty query', () async {
      editor.apply(const EditOperation(6, 6, '[['), selectAfter: true);
      await Future<void>.delayed(Duration.zero);
      expect(autoController.state.visible, isTrue);

      // Dismiss with Esc
      editor.focusNode.onKeyEvent!(
        editor.focusNode,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
      );
      expect(autoController.state.visible, isFalse);

      // Ctrl+Space forces trigger
      autoController.trigger(force: true);
      expect(autoController.state.visible, isTrue);
      expect(autoController.state.items, isNotEmpty);
    });

    test('stale async result is dropped (resolve two heading lookups out of order)', () async {
      final completer1 = Completer<NoteIndex>();
      final completer2 = Completer<NoteIndex>();

      final delegatingContainer = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(
            () => _ControllableNoteIndexNotifier([completer1, completer2]),
          ),
          editorRegistryProvider.overrideWithValue(registry),
          noteDocumentStoreProvider.overrideWithValue(store),
          switcherItemsProvider.overrideWith((ref) => []),
        ],
      );

      final ctrl = delegatingContainer.read(
        autocompleteControllerProvider('tab2').notifier,
      );
      ctrl.attach(editor);

      // Lookup 1: [[Alpha#A
      editor.apply(const EditOperation(6, 6, '[[Alpha#A'), selectAfter: true);
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.state.loading, isTrue);

      // Invalidate noteIndexProvider so lookup 2 requests a fresh future
      delegatingContainer.invalidate(noteIndexProvider);

      // Lookup 2: quickly change to [[Alpha#B
      editor.apply(const EditOperation(14, 15, 'B'), selectAfter: true);
      await Future<void>.delayed(Duration.zero);

      // Complete lookup 2 first
      completer2.complete(index);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(ctrl.state.items, isNotEmpty);
      expect(ctrl.state.items.first.primary, equals('Beta Heading'));

      // Now complete stale lookup 1
      completer1.complete(index);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Lookup 1's result is dropped! Items still show 'Beta Heading'
      expect(ctrl.state.items.first.primary, equals('Beta Heading'));

      ctrl.detach();
      delegatingContainer.dispose();
    });
  });
}
