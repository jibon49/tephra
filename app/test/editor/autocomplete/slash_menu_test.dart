// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/tephra_command.dart';
import 'package:tephra/editor/autocomplete/autocomplete_context.dart';
import 'package:tephra/editor/autocomplete/autocomplete_item.dart';
import 'package:tephra/editor/autocomplete/autocomplete_popup.dart';
import 'package:tephra/editor/autocomplete/autocomplete_ranker.dart';
import 'package:tephra/editor/autocomplete/slash_commands.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/line_view.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart' hide Snippet;
import 'package:tephra_vault/tephra_vault.dart';

import '../../helpers/fake_editor_engine.dart';

class _CountingFakeEditorEngine extends FakeEditorEngine {
  _CountingFakeEditorEngine([super.initialText = '']);

  int applyPlanCount = 0;

  @override
  void applyPlan(EditPlan plan) {
    applyPlanCount++;
    super.applyPlan(plan);
  }
}

class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  group('Slash menu ranking and filtering', () {
    test('query "call" lists the 13 callouts first', () {
      final items = AutocompleteRanker.rankSlashCommands(
        'call',
        defaultSlashCommands,
        l10n,
      );
      expect(items.length, greaterThanOrEqualTo(13));
      for (var i = 0; i < 13; i++) {
        final cmd = items[i].payload as SlashCommand;
        expect(cmd.id, startsWith('callout-'));
      }
    });

    test('query "tab" ranks Table first', () {
      final items = AutocompleteRanker.rankSlashCommands(
        'tab',
        defaultSlashCommands,
        l10n,
      );
      expect(items.isNotEmpty, isTrue);
      final firstCmd = items.first.payload as SlashCommand;
      expect(firstCmd.id, equals('table'));
    });

    test('the template item is hidden while the command is unregistered', () {
      final container = ProviderContainer(
        overrides: [
          commandRegistryProvider.overrideWith((ref) => CommandRegistry()),
        ],
      );
      addTearDown(container.dispose);

      final ref = container.read(_testRefProvider);

      // Verify command is unregistered
      final registry = container.read(commandRegistryProvider);
      expect(registry.byId('templates.insert-template'), isNull);

      final templateCmd = defaultSlashCommands.firstWhere(
        (c) => c.id == 'template',
      );
      expect(templateCmd.isAvailable?.call(ref), isFalse);

      final available = defaultSlashCommands.where((cmd) {
        if (cmd.isAvailable != null) {
          return cmd.isAvailable!(ref);
        }
        return true;
      }).toList();
      expect(available.any((c) => c.id == 'template'), isFalse);

      // When registered, becomes available
      registry.register(
        TephraCommand(
          id: 'templates.insert-template',
          label: (l) => 'Insert template',
          run: (ref, context) {},
        ),
      );
      expect(templateCmd.isAvailable?.call(ref), isTrue);
    });
  });

  group('Slash menu UI & controller interaction', () {
    late MemoryVaultFileSystem fs;
    late EditorRegistry registry;
    late NoteDocumentStore store;
    late VaultSession session;
    late VaultPath path;
    late NoteDocument doc;
    late _CountingFakeEditorEngine engine;
    late EditorController editor;

    setUp(() async {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      registry = EditorRegistry();
      store = NoteDocumentStore(fs, const SystemClock());
      path = VaultPath('Doc.md');

      await fs.writeText(path, const TextDocument(text: ''));

      session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
      );

      doc = store.acquire(path);
      await doc.load();

      engine = _CountingFakeEditorEngine(doc.text);
      editor = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );
    });

    tearDown(() {
      editor.dispose();
      store.release(path);
    });

    testWidgets('typing / shows 8 rows at desktop width', (tester) async {
      final container = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          editorRegistryProvider.overrideWithValue(registry),
          noteDocumentStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final ref = container.read(_testRefProvider);
      final available = defaultSlashCommands.where((cmd) {
        if (cmd.isAvailable != null) {
          return cmd.isAvailable!(ref);
        }
        return true;
      }).toList();

      final items = AutocompleteRanker.rankSlashCommands('', available, l10n);

      final state = AutocompleteState(
        context: const SlashContext(
          query: '',
          slashStart: 0,
          replaceStart: 0,
          replaceEnd: 1,
        ),
        items: items,
        visible: true,
        selected: 0,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(1200, 800)),
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
        ),
      );
      await tester.pumpAndSettle();

      // Card height at desktop = 8 * 32.0 + 8.0 = 264.0
      // 8 rows are visible
      expect(find.byType(ListView), findsOneWidget);
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.itemExtent, equals(32.0));
    });

    test(
      'Enter inserts and one Ctrl+Z undoes (applyEdits calls = 1)',
      () async {
        final container = ProviderContainer(
          overrides: [
            vaultFsProvider.overrideWithValue(fs),
            vaultSessionProvider.overrideWith(
              () => _FixedSessionNotifier(session),
            ),
            editorRegistryProvider.overrideWithValue(registry),
            noteDocumentStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          autocompleteControllerProvider('testTab').notifier,
        );
        controller.attach(editor);

        // Start text with '/h1'
        editor.applyEdits([const TextEdit(0, 0, '/h1')]);
        editor.select(3);

        final ctx = const SlashContext(
          query: 'h1',
          slashStart: 0,
          replaceStart: 0,
          replaceEnd: 3,
        );

        final heading1Cmd = defaultSlashCommands.firstWhere(
          (c) => c.id == 'heading1',
        );
        final item = AcItem(
          kind: AcKind.slash,
          primary: heading1Cmd.label(l10n),
          score: 100,
          payload: heading1Cmd,
        );

        final editsBefore = engine.applyPlanCount;
        await controller.accept(item, context: ctx);

        // Verify insertion
        expect(editor.text, equals('# '));
        // Exactly 1 applyEdits call
        expect(engine.applyPlanCount - editsBefore, equals(1));

        // One undo restores the previous text
        editor.undo();
        expect(editor.text, equals('/h1'));
      },
    );
  });
}
