// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/explorer/providers.dart';
import 'package:tephra/links/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

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

  group('UnlinkedMentionLinker', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late ProviderContainer container;
    late UnlinkedMentionLinker linker;
    late EditorRegistry registry;
    late NoteDocumentStore store;
    late GlobalKey<ScaffoldMessengerState> messengerKey;

    Future<void> setupContainer({bool useMarkdownLinks = false}) async {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      await fs.writeText(
        VaultPath('Alpha.md'),
        const TextDocument(text: '# Alpha'),
      );
      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();

      registry = EditorRegistry();
      store = NoteDocumentStore(fs, const SystemClock());
      messengerKey = GlobalKey<ScaffoldMessengerState>();

      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: VaultSettings(useMarkdownLinks: useMarkdownLinks),
      );

      container = ProviderContainer(
        overrides: [
          vaultFsProvider.overrideWithValue(fs),
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          editorRegistryProvider.overrideWithValue(registry),
          noteDocumentStoreProvider.overrideWithValue(store),
          scaffoldMessengerKeyProvider.overrideWithValue(messengerKey),
        ],
      );

      linker = container.read(unlinkedMentionLinkerProvider);
    }

    test(
      'disk file "I like alpha." becomes "I like [[Alpha|alpha]]."',
      () async {
        await setupContainer();
        final notePath = VaultPath('Note.md');
        await fs.writeText(notePath, const TextDocument(text: 'I like alpha.'));

        final mention = UnlinkedMention(
          source: notePath,
          start: 7,
          end: 12,
          line: 0,
          matchedText: 'alpha',
          snippet: 'I like alpha.',
          snippetStart: 7,
          snippetEnd: 12,
        );

        final success = await linker.link(mention, VaultPath('Alpha.md'));
        expect(success, isTrue);

        final updatedDoc = await fs.readText(notePath);
        expect(updatedDoc.text, equals('I like [[Alpha|alpha]].'));
      },
    );

    test('text "Alpha" exact becomes "[[Alpha]]"', () async {
      await setupContainer();
      final notePath = VaultPath('Note.md');
      await fs.writeText(notePath, const TextDocument(text: 'Alpha is great.'));

      final mention = UnlinkedMention(
        source: notePath,
        start: 0,
        end: 5,
        line: 0,
        matchedText: 'Alpha',
        snippet: 'Alpha is great.',
        snippetStart: 0,
        snippetEnd: 5,
      );

      final success = await linker.link(mention, VaultPath('Alpha.md'));
      expect(success, isTrue);

      final updatedDoc = await fs.readText(notePath);
      expect(updatedDoc.text, equals('[[Alpha]] is great.'));
    });

    test('with useMarkdownLinks becomes "[alpha](Alpha.md)"', () async {
      await setupContainer(useMarkdownLinks: true);
      final notePath = VaultPath('Note.md');
      await fs.writeText(notePath, const TextDocument(text: 'I like alpha.'));

      final mention = UnlinkedMention(
        source: notePath,
        start: 7,
        end: 12,
        line: 0,
        matchedText: 'alpha',
        snippet: 'I like alpha.',
        snippetStart: 7,
        snippetEnd: 12,
      );

      final success = await linker.link(mention, VaultPath('Alpha.md'));
      expect(success, isTrue);

      final updatedDoc = await fs.readText(notePath);
      expect(updatedDoc.text, equals('I like [alpha](Alpha.md).'));
    });

    test('changed text -> no write, refresh message', () async {
      await setupContainer();
      final notePath = VaultPath('Note.md');
      await fs.writeText(
        notePath,
        const TextDocument(text: 'I like modified text.'),
      );

      final mention = UnlinkedMention(
        source: notePath,
        start: 7,
        end: 12,
        line: 0,
        matchedText: 'alpha',
        snippet: 'I like alpha.',
        snippetStart: 7,
        snippetEnd: 12,
      );

      final success = await linker.link(mention, VaultPath('Alpha.md'));
      expect(success, isFalse);

      final untouchedDoc = await fs.readText(notePath);
      expect(untouchedDoc.text, equals('I like modified text.'));
    });
  });
}
