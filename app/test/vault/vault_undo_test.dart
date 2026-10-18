// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/explorer/providers.dart';
import 'package:tephra/links/link_rename_service.dart';
import 'package:tephra/links/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document_store.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/vault/vault_undo.dart';
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

  group('VaultUndo', () {
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

    test('rename then undo -> all files byte-identical to before and file back at old path', () async {
      final targetPath = VaultPath('Target.md');
      final n1Path = VaultPath('N1.md');
      final n2Path = VaultPath('N2.md');

      await fs.writeText(
        targetPath,
        const TextDocument(text: '# Target\nInitial content\n'),
      );
      await fs.writeText(
        n1Path,
        const TextDocument(text: 'Intro\n[[Target]] and [[Target#H|H]]\n'),
      );
      await fs.writeText(
        n2Path,
        const TextDocument(text: 'See [target](Target.md)\n'),
      );

      final origTargetBytes = await fs.readBytes(targetPath);
      final origN1Bytes = await fs.readBytes(n1Path);
      final origN2Bytes = await fs.readBytes(n2Path);

      await index.reconcile();

      final renamedPath = VaultPath('Renamed.md');
      final outcome = await service.renameOrMove(targetPath, renamedPath);

      expect(outcome.links, equals(3));
      expect(await fs.stat(targetPath), isNull);
      expect(await fs.stat(renamedPath), isNotNull);

      // Undo
      final undoResult = await container
          .read(vaultUndoStackProvider.notifier)
          .undoLast();

      expect(undoResult, isNotNull);
      expect(undoResult!.conflicts, equals(0));

      // File back at old path
      expect(await fs.stat(renamedPath), isNull);
      expect(await fs.stat(targetPath), isNotNull);

      // Byte-identical check
      expect(await fs.readBytes(targetPath), equals(origTargetBytes));
      expect(await fs.readBytes(n1Path), equals(origN1Bytes));
      expect(await fs.readBytes(n2Path), equals(origN2Bytes));
    });

    test('edit one rewritten note after rename, then undo -> that note left as is, others restored, result reports 1 conflict', () async {
      final targetPath = VaultPath('Target.md');
      final n1Path = VaultPath('N1.md');
      final n2Path = VaultPath('N2.md');

      await fs.writeText(targetPath, const TextDocument(text: '# Target\n'));
      await fs.writeText(
        n1Path,
        const TextDocument(text: 'Intro\n[[Target]]\n'),
      );
      await fs.writeText(
        n2Path,
        const TextDocument(text: 'Link: [[Target]]\n'),
      );

      final origN1Bytes = await fs.readBytes(n1Path);

      await index.reconcile();

      final renamedPath = VaultPath('Renamed.md');
      await service.renameOrMove(targetPath, renamedPath);

      // Edit N2 after the rename
      const editedN2Text = 'User edited N2 independently after rename\n';
      await fs.writeText(n2Path, const TextDocument(text: editedN2Text));

      // Undo
      final undoResult = await container
          .read(vaultUndoStackProvider.notifier)
          .undoLast();

      expect(undoResult, isNotNull);
      expect(undoResult!.conflicts, equals(1));

      // N2 was left as is
      expect((await fs.readText(n2Path)).text, equals(editedN2Text));

      // N1 was restored to before
      expect(await fs.readBytes(n1Path), equals(origN1Bytes));

      // Target was restored
      expect(await fs.stat(renamedPath), isNull);
      expect(await fs.stat(targetPath), isNotNull);
    });
  });
}
