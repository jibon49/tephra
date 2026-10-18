// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/quick_switcher_items.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';
import 'package:tephra/editor/autocomplete/autocomplete_item.dart';
import 'package:tephra/editor/autocomplete/autocomplete_popup.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutocompletePopup', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late EditorRegistry registry;
    late NoteDocumentStore store;
    late VaultSession session;
    late VaultPath path;
    late NoteDocument doc;
    late FakeEditorEngine engine;
    late EditorController editor;

    setUp(() async {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      index = await NoteIndex.open(':memory:', fs);
      registry = EditorRegistry();
      store = NoteDocumentStore(fs, const SystemClock());
      path = VaultPath('Doc.md');

      await fs.writeText(path, const TextDocument(text: '[[Alpha'));
      await index.reconcile();

      session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
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
    });

    tearDown(() async {
      editor.dispose();
      store.release(path);
      await index.close();
    });

    Widget buildTestWidget({
      required Size size,
      EdgeInsets viewInsets = EdgeInsets.zero,
      required AutocompleteState state,
    }) {
      return ProviderScope(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          editorRegistryProvider.overrideWithValue(registry),
          noteDocumentStoreProvider.overrideWithValue(store),
          switcherItemsProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: MediaQuery(
              data: MediaQueryData(size: size, viewInsets: viewInsets),
              child: Stack(
                children: [
                  AutocompletePopup(
                    tabId: 'testTab',
                    controller: editor,
                    state: state,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('at 1200 dp the card is below the caret rect', (tester) async {
      engine.globalCaretRect = const Rect.fromLTWH(100, 100, 2, 20);

      final state = AutocompleteState(
        context: const NoteLinkContext(
          query: 'Alpha',
          embed: false,
          openStart: 0,
          replaceStart: 2,
          replaceEnd: 7,
          closerPresent: false,
        ),
        items: [
          AcItem(
            kind: AcKind.note,
            primary: 'Alpha',
            score: 1000,
            matchRanges: const [],
            payload: VaultPath('Alpha.md'),
          ),
        ],
        visible: true,
      );

      await tester.pumpWidget(
        buildTestWidget(size: const Size(1200, 800), state: state),
      );
      await tester.pumpAndSettle();

      final positionedFinder = find.byType(Positioned);
      expect(positionedFinder, findsOneWidget);
      final positioned = tester.widget<Positioned>(positionedFinder);

      // Card is placed below caret: top = caret bottom (120) + 4 = 124
      expect(positioned.top, equals(124.0));
      expect(positioned.bottom, isNull);
      expect(positioned.left, equals(100.0));
    });

    testWidgets(
      'with the caret 100 dp above the window bottom it flips above',
      (tester) async {
        // Window height 800. Caret top 700, height 20 -> caret bottom 720 (80 dp above bottom).
        engine.globalCaretRect = const Rect.fromLTWH(100, 700, 2, 20);

        final state = AutocompleteState(
          context: const NoteLinkContext(
            query: 'Alpha',
            embed: false,
            openStart: 0,
            replaceStart: 2,
            replaceEnd: 7,
            closerPresent: false,
          ),
          items: [
            for (var i = 0; i < 5; i++)
              AcItem(
                kind: AcKind.note,
                primary: 'Note $i',
                score: 1000 - i,
                matchRanges: const [],
                payload: VaultPath('Note $i.md'),
              ),
          ],
          visible: true,
        );

        await tester.pumpWidget(
          buildTestWidget(size: const Size(1200, 800), state: state),
        );
        await tester.pumpAndSettle();

        final positioned = tester.widget<Positioned>(find.byType(Positioned));

        // Flips above caret: bottom = windowHeight - caret.top + 4 = 800 - 700 + 4 = 104
        expect(positioned.top, isNull);
        expect(positioned.bottom, equals(104.0));
        expect(positioned.left, equals(100.0));
      },
    );

    testWidgets(
      'at 400 dp the sheet sits above the keyboard (viewInsets.bottom = 300) and rows are 48 dp',
      (tester) async {
        final state = AutocompleteState(
          context: const NoteLinkContext(
            query: 'Alpha',
            embed: false,
            openStart: 0,
            replaceStart: 2,
            replaceEnd: 7,
            closerPresent: false,
          ),
          items: [
            AcItem(
              kind: AcKind.note,
              primary: 'Alpha',
              score: 1000,
              matchRanges: const [],
              payload: VaultPath('Alpha.md'),
            ),
          ],
          visible: true,
        );

        await tester.pumpWidget(
          buildTestWidget(
            size: const Size(400, 800),
            viewInsets: const EdgeInsets.only(bottom: 300),
            state: state,
          ),
        );
        await tester.pumpAndSettle();

        final positioned = tester.widget<Positioned>(find.byType(Positioned));

        // Sheet sits above keyboard toolbar: bottom = 300 + 48 = 348
        expect(positioned.bottom, equals(348.0));
        expect(positioned.left, equals(0.0));
        expect(positioned.right, equals(0.0));

        // Row height is 48 dp on phone layout
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.itemExtent, equals(48.0));
      },
    );

    testWidgets(
      'tapping the continue button calls accept with continueIntoSubpath: true',
      (tester) async {
        // Initial text '[[Alpha'
        final state = AutocompleteState(
          context: const NoteLinkContext(
            query: 'Alpha',
            embed: false,
            openStart: 0,
            replaceStart: 2,
            replaceEnd: 7,
            closerPresent: false,
          ),
          items: [
            AcItem(
              kind: AcKind.note,
              primary: 'Alpha',
              score: 1000,
              matchRanges: const [],
              payload: VaultPath('Alpha.md'),
            ),
          ],
          visible: true,
        );

        await tester.pumpWidget(
          buildTestWidget(size: const Size(400, 800), state: state),
        );
        await tester.pumpAndSettle();

        // Find the continue button (with '#' icon text)
        final continueBtn = find.widgetWithText(IconButton, '#');
        expect(continueBtn, findsOneWidget);

        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        // Tapping continue inserted '#|]]' and continued completion into heading
        expect(editor.text, equals('[[Alpha#]]'));
        expect(editor.selection.baseOffset, equals(8));
      },
    );

    testWidgets('20 items at desktop show 8 rows', (tester) async {
      final state = AutocompleteState(
        context: const NoteLinkContext(
          query: 'Item',
          embed: false,
          openStart: 0,
          replaceStart: 2,
          replaceEnd: 7,
          closerPresent: false,
        ),
        items: [
          for (var i = 0; i < 20; i++)
            AcItem(
              kind: AcKind.note,
              primary: 'Item $i',
              score: 1000 - i,
              matchRanges: const [],
              payload: VaultPath('Item $i.md'),
            ),
        ],
        visible: true,
      );

      await tester.pumpWidget(
        buildTestWidget(size: const Size(1200, 800), state: state),
      );
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(find.byType(Positioned));

      // 8 rows * 32 dp + 8 dp padding = 264 dp
      expect(positioned.height, equals(8 * 32.0 + 8.0));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.itemExtent, equals(32.0));
    });
  });
}
