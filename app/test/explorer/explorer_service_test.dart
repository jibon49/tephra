// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/edit_operation.dart';
import 'package:tephra/explorer/explorer_service.dart';
import 'package:tephra/explorer/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

extension on VaultFileSystem {
  Future<bool> exists(VaultPath path) async => (await stat(path)) != null;
}

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

class FakeSystemTrash implements SystemTrash {
  FakeSystemTrash({this.result = true});
  final bool result;
  final List<String> trashed = [];

  @override
  Future<bool> moveToTrash(
    String absolutePath, {
    required bool isFolder,
  }) async {
    trashed.add(absolutePath);
    return result;
  }
}

void main() {
  group('explorer_service_test', () {
    late MemoryVaultFileSystem fs;
    late VaultSession session;
    late ProviderContainer container;
    late ExplorerService service;
    late GlobalKey<ScaffoldMessengerState> messengerKey;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      fs = MemoryVaultFileSystem(caseInsensitive: true);
      session = VaultSession(
        vaultId: 'v1',
        rootDir: '/vault',
        name: 'test-vault',
        fs: fs,
        settings: const VaultSettings(),
      );
      messengerKey = GlobalKey<ScaffoldMessengerState>();

      container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => TestVaultSessionNotifier(session),
          ),
          scaffoldMessengerKeyProvider.overrideWithValue(messengerKey),
        ],
      );
      service = container.read(explorerServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'createNote creates Untitled.md, selects, expands, and starts rename',
      () async {
        final path1 = await service.createNote(VaultPath.root);
        expect(path1, equals(VaultPath('Untitled.md')));
        expect(container.read(explorerSelectedProvider), equals(path1));
        expect(container.read(explorerRenamingProvider), equals(path1));

        // Second note creates Untitled 1.md
        final path2 = await service.createNote(VaultPath.root);
        expect(path2, equals(VaultPath('Untitled 1.md')));
        expect(container.read(explorerSelectedProvider), equals(path2));
        expect(container.read(explorerRenamingProvider), equals(path2));
      },
    );

    test(
      'createFolder creates Untitled folder then Untitled folder 1',
      () async {
        final f1 = await service.createFolder(VaultPath.root);
        expect(f1, equals(VaultPath('Untitled folder')));
        expect(container.read(explorerSelectedProvider), equals(f1));
        expect(container.read(explorerRenamingProvider), equals(f1));

        final f2 = await service.createFolder(VaultPath.root);
        expect(f2, equals(VaultPath('Untitled folder 1')));
        expect(container.read(explorerSelectedProvider), equals(f2));
        expect(container.read(explorerRenamingProvider), equals(f2));
      },
    );

    test('rename note A.md -> B gives B.md, typing B.md gives B.md without double extension', () async {
      await fs.writeText(
        VaultPath('A.md'),
        const TextDocument(text: 'content A'),
      );

      final renamed1 = await service.rename(VaultPath('A.md'), 'B');
      expect(renamed1, equals(VaultPath('B.md')));
      expect(await fs.exists(VaultPath('B.md')), isTrue);
      expect(await fs.exists(VaultPath('A.md')), isFalse);

      final renamed2 = await service.rename(VaultPath('B.md'), 'C.md');
      expect(renamed2, equals(VaultPath('C.md')));
      expect(await fs.exists(VaultPath('C.md')), isTrue);
    });

    test('rename folder F -> G moves children and retargets open tab history and store', () async {
      await fs.createFolder(VaultPath('F'));
      await fs.writeText(
        VaultPath('F/x.md'),
        const TextDocument(text: 'x content'),
      );

      // Open F/x.md in workspace
      container.read(workspaceProvider.notifier).openPath(VaultPath('F/x.md'));
      final activeContent = container
          .read(workspaceProvider)
          .focusedTab
          ?.content;
      expect(
        (activeContent as FileTabContent).path,
        equals(VaultPath('F/x.md')),
      );

      // Acquire doc in store
      final store = container.read(noteDocumentStoreProvider);
      final doc = store.acquire(VaultPath('F/x.md'));
      await doc.load();

      // Rename folder F -> G
      final newFolder = await service.rename(VaultPath('F'), 'G');
      expect(newFolder, equals(VaultPath('G')));
      expect(await fs.exists(VaultPath('G/x.md')), isTrue);
      expect(await fs.exists(VaultPath('F/x.md')), isFalse);

      // Verify workspace tab retargeted
      final updatedContent = container
          .read(workspaceProvider)
          .focusedTab
          ?.content;
      expect(
        (updatedContent as FileTabContent).path,
        equals(VaultPath('G/x.md')),
      );

      // Verify doc path retargeted in store
      expect(doc.path, equals(VaultPath('G/x.md')));
    });

    test('rename to existing name throws FileConflictException', () async {
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: 'A'));
      await fs.writeText(VaultPath('B.md'), const TextDocument(text: 'B'));

      expect(
        () => service.rename(VaultPath('A.md'), 'B'),
        throwsA(isA<FileConflictException>()),
      );
    });

    test(
      'case-only rename a.md -> A.md is allowed on case-insensitive fs',
      () async {
        await fs.writeText(VaultPath('a.md'), const TextDocument(text: 'a'));
        final renamed = await service.rename(VaultPath('a.md'), 'A.md');
        expect(renamed, equals(VaultPath('A.md')));
        expect(await fs.exists(VaultPath('A.md')), isTrue);
      },
    );

    test('invalid names throw InvalidPathException', () async {
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: 'A'));

      expect(
        () => service.rename(VaultPath('A.md'), ''),
        throwsA(isA<InvalidPathException>()),
      );
      expect(
        () => service.rename(VaultPath('A.md'), 'a/b'),
        throwsA(isA<InvalidPathException>()),
      );
      expect(
        () => service.rename(VaultPath('A.md'), 'a:b'),
        throwsA(isA<InvalidPathException>()),
      );
      expect(
        () => service.rename(VaultPath('A.md'), 'con'),
        throwsA(isA<InvalidPathException>()),
      );
    });

    test('dirty buffer is flushed before move/rename', () async {
      await fs.writeText(
        VaultPath('A.md'),
        const TextDocument(text: 'original'),
      );
      final store = container.read(noteDocumentStoreProvider);
      final doc = store.acquire(VaultPath('A.md'));
      await doc.load();

      doc.edit(const EditOperation(0, 8, 'modified text'));
      expect(doc.isDirty, isTrue);

      await service.rename(VaultPath('A.md'), 'B');
      final newDoc = await fs.readText(VaultPath('B.md'));
      expect(newDoc.text, equals('modified text'));
    });

    test('move into a descendant is refused with StateError', () async {
      await fs.createFolder(VaultPath('Folder'));
      await fs.createFolder(VaultPath('Folder/Sub'));

      expect(
        () => service.move(VaultPath('Folder'), VaultPath('Folder/Sub')),
        throwsA(isA<StateError>()),
      );
    });

    test('move conflict throws FileConflictException', () async {
      await fs.writeText(VaultPath('A.md'), const TextDocument(text: 'A'));
      await fs.createFolder(VaultPath('Target'));
      await fs.writeText(
        VaultPath('Target/A.md'),
        const TextDocument(text: 'existing A'),
      );

      expect(
        () => service.move(VaultPath('A.md'), VaultPath('Target')),
        throwsA(isA<FileConflictException>()),
      );
    });

    test('duplicate is byte-exact for CRLF+BOM file and names Name 1.md then Name 2.md', () async {
      // UTF-8 BOM + 'Hello\r\n'
      final originalBytes = [
        0xEF,
        0xBB,
        0xBF,
        0x48,
        0x65,
        0x6C,
        0x6C,
        0x6F,
        0x0D,
        0x0A,
      ];
      await fs.writeBytes(VaultPath('Name.md'), originalBytes);

      final dup1 = await service.duplicate(VaultPath('Name.md'));
      expect(dup1, equals(VaultPath('Name 1.md')));
      final dup1Bytes = await fs.readBytes(dup1);
      expect(dup1Bytes, equals(originalBytes));

      final dup2 = await service.duplicate(VaultPath('Name.md'));
      expect(dup2, equals(VaultPath('Name 2.md')));
      final dup2Bytes = await fs.readBytes(dup2);
      expect(dup2Bytes, equals(originalBytes));
    });

    test('delete closes open tab and drops document from store', () async {
      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'content'),
      );
      container.read(workspaceProvider.notifier).openPath(VaultPath('Note.md'));
      expect(container.read(workspaceProvider).focusedTab, isNotNull);

      final store = container.read(noteDocumentStoreProvider);
      final doc = store.acquire(VaultPath('Note.md'));
      await doc.load();
      expect(store.peek(VaultPath('Note.md')), isNotNull);

      await service.delete(VaultPath('Note.md'));
      expect(await fs.exists(VaultPath('Note.md')), isFalse);
      expect(container.read(workspaceProvider).focusedTab, isNull);
      expect(store.peek(VaultPath('Note.md')), isNull);
    });
  });
}
