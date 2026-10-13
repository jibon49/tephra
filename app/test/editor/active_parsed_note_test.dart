// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('activeParsedNoteProvider', () {
    late MemoryVaultFileSystem fs;
    late NoteDocumentStore store;
    late ProviderContainer container;

    late ProviderSubscription<ParsedNote?> sub;

    setUp(() {
      fs = MemoryVaultFileSystem();
      store = NoteDocumentStore(
        fs,
        const SystemClock(),
        parseService: const ParseService(),
      );
      container = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          noteDocumentStoreProvider.overrideWithValue(store),
        ],
      );
      sub = container.listen(activeParsedNoteProvider, (_, _) {});
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    test('lifecycle: null when no note, yields parse after 300ms, updates on edit and tab switch', () async {
      // 1. No note focused -> null
      expect(container.read(activeParsedNoteProvider), isNull);

      final note1 = VaultPath('note1.md');
      final note2 = VaultPath('note2.md');
      await fs.writeText(
        note1,
        const TextDocument(text: '# Heading 1\nBody text'),
      );
      await fs.writeText(
        note2,
        const TextDocument(text: '## Heading A\n## Heading B'),
      );

      // 2. Open note1 in workspace
      container.read(workspaceProvider.notifier).openPath(note1);

      Future<void> waitFor(
        bool Function() condition, {
        Duration timeout = const Duration(seconds: 2),
      }) async {
        final end = DateTime.now().add(timeout);
        while (!condition() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }

      // Initially null before 300ms debounce
      expect(container.read(activeParsedNoteProvider), isNull);

      // Wait for parse debounce
      await waitFor(() => container.read(activeParsedNoteProvider) != null);
      final parse1 = container.read(activeParsedNoteProvider);
      expect(parse1, isNotNull);
      expect(parse1!.headings.length, equals(1));
      expect(parse1.headings.first.level, equals(1));

      // 3. Edit document -> re-parses after 300ms
      final doc1 = store.acquire(note1);
      doc1.setText('# H1\n# H2\n# H3');
      await waitFor(
        () => container.read(activeParsedNoteProvider)?.headings.length == 3,
      );

      final parse1Updated = container.read(activeParsedNoteProvider);
      expect(parse1Updated, isNotNull);
      expect(parse1Updated!.headings.length, equals(3));

      // 4. Switch focused tab to note2
      container.read(workspaceProvider.notifier).openPath(note2, newTab: true);
      await waitFor(
        () => container.read(activeParsedNoteProvider)?.headings.length == 2,
      );

      final parse2 = container.read(activeParsedNoteProvider);
      expect(parse2, isNotNull);
      expect(parse2!.headings.length, equals(2));

      // 5. Close all tabs -> null
      final pane = container.read(workspaceProvider).currentPane;
      if (pane != null) {
        for (final tab in List.of(pane.tabs)) {
          container.read(workspaceProvider.notifier).closeTab(pane.id, tab.id);
        }
      }

      expect(container.read(activeParsedNoteProvider), isNull);
    });
  });
}
