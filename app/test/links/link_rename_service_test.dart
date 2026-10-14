// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/explorer/providers.dart';
import 'package:tephra/links/link_rename_service.dart';
import 'package:tephra/links/providers.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/fake_editor_engine.dart';

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

  group('LinkRenameService', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late ProviderContainer container;
    late LinkRenameService service;
    late EditorRegistry registry;
    late NoteDocumentStore store;
    late GlobalKey<ScaffoldMessengerState> messengerKey;

    setUp(() async {
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      index = await NoteIndex.open(':memory:', fs);
      registry = EditorRegistry();
      store = NoteDocumentStore(fs, const SystemClock());
      messengerKey = GlobalKey<ScaffoldMessengerState>();

      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(alwaysUpdateLinks: true),
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

      service = container.read(linkRenameServiceProvider);
    });

    tearDown(() async {
      container.dispose();
      await index.close();
    });

    test(
      '(a) disk files rewritten, outcome reports 3 links in 2 files',
      () async {
        await fs.writeText(
          VaultPath('Target.md'),
          const TextDocument(text: '# Target\n'),
        );
        await fs.writeText(
          VaultPath('N1.md'),
          const TextDocument(text: 'Intro\n[[Target]] and [[Target#H|H]]\n'),
        );
        await fs.writeText(
          VaultPath('N2.md'),
          const TextDocument(text: 'Check [link](Target.md)\n'),
        );

        await index.reconcile();

        final outcome = await service.renameOrMove(
          VaultPath('Target.md'),
          VaultPath('Renamed.md'),
        );

        expect(outcome.links, equals(3));
        expect(outcome.files, equals(2));
        expect(outcome.skipped, isEmpty);

        final n1After = (await fs.readText(VaultPath('N1.md'))).text;
        expect(n1After, equals('Intro\n[[Renamed]] and [[Renamed#H|H]]\n'));

        final n2After = (await fs.readText(VaultPath('N2.md'))).text;
        expect(n2After, equals('Check [link](Renamed.md)\n'));

        expect(await fs.stat(VaultPath('Target.md')), isNull);
        expect(await fs.stat(VaultPath('Renamed.md')), isNotNull);
      },
    );

    test('(b) a note open in an EditorController with unsaved edits receives applyEdits and disk is not written', () async {
      final targetPath = VaultPath('Target.md');
      final n1Path = VaultPath('N1.md');

      await fs.writeText(targetPath, const TextDocument(text: '# Target\n'));
      const originalDiskN1 = 'Initial line\n[[Target]]\n';
      await fs.writeText(n1Path, const TextDocument(text: originalDiskN1));

      await index.reconcile();

      final doc = store.acquire(n1Path);
      await doc.load();

      final engine = FakeEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
        registry: registry,
      );

      // Add unsaved edits to controller
      controller.applyEdits([const EditOperation(0, 0, 'Unsaved line\n')]);
      expect(
        controller.text,
        equals('Unsaved line\nInitial line\n[[Target]]\n'),
      );

      final outcome = await service.renameOrMove(
        targetPath,
        VaultPath('Renamed.md'),
      );

      expect(outcome.links, equals(1));
      expect(outcome.files, equals(1));

      // Buffer was updated
      expect(
        controller.text,
        equals('Unsaved line\nInitial line\n[[Renamed]]\n'),
      );

      // Disk was NOT written by the service
      final diskN1 = (await fs.readText(n1Path)).text;
      expect(diskN1, equals(originalDiskN1));

      controller.dispose();
    });

    test(
      '(c) alwaysUpdateLinks == false + "Don\'t update" -> move only',
      () async {
        final targetPath = VaultPath('Target.md');
        final n1Path = VaultPath('N1.md');

        await fs.writeText(targetPath, const TextDocument(text: '# Target\n'));
        await fs.writeText(
          n1Path,
          const TextDocument(text: 'Link: [[Target]]\n'),
        );

        await index.reconcile();

        // Session with alwaysUpdateLinks: false
        final session = VaultSession(
          vaultId: 'test-vault',
          rootDir: '/memory',
          name: 'Test',
          fs: fs,
          settings: const VaultSettings(alwaysUpdateLinks: false),
        );
        container.dispose();
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
        service = container.read(linkRenameServiceProvider);

        final outcome = await service.renameOrMove(
          targetPath,
          VaultPath('Renamed.md'),
          onConfirmUpdate: ({required links, required files}) async => false,
        );

        expect(outcome.links, equals(0));
        expect(outcome.files, equals(0));

        // Move happened
        expect(await fs.stat(targetPath), isNull);
        expect(await fs.stat(VaultPath('Renamed.md')), isNotNull);

        // Linking note was NOT updated
        final n1Text = (await fs.readText(n1Path)).text;
        expect(n1Text, equals('Link: [[Target]]\n'));
      },
    );

    test('(d) target exists throws FileConflictException', () async {
      await fs.writeText(
        VaultPath('Target.md'),
        const TextDocument(text: '# Target\n'),
      );
      await fs.writeText(
        VaultPath('Existing.md'),
        const TextDocument(text: '# Existing\n'),
      );

      await index.reconcile();

      expect(
        () => service.renameOrMove(
          VaultPath('Target.md'),
          VaultPath('Existing.md'),
        ),
        throwsA(isA<FileConflictException>()),
      );
    });

    test('(e) malformed source skipped and reported', () async {
      final targetPath = VaultPath('Target.md');
      final malformedPath = VaultPath('Bad.md');

      await fs.writeText(targetPath, const TextDocument(text: '# Target\n'));
      // Write malformed bytes (invalid UTF-8 sequence)
      fs.putBytes('Bad.md', [0xC0, 0xAF]);

      await fs.writeText(
        VaultPath('Good.md'),
        const TextDocument(text: 'Link: [[Target]]\n'),
      );

      await index.reconcile();

      final outcome = await service.renameOrMove(
        targetPath,
        VaultPath('Renamed.md'),
      );

      expect(outcome.links, equals(1));
      expect(outcome.files, equals(1));
      // Target was moved
      expect(await fs.stat(VaultPath('Renamed.md')), isNotNull);
      // Malformed file still exists untouched
      expect(await fs.readBytes(malformedPath), equals([0xC0, 0xAF]));
    });
  });
}
