// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('NoteCreator', () {
    late MemoryVaultFileSystem fs;
    late ProviderContainer container;

    setUp(() {
      fs = MemoryVaultFileSystem();
      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
      );

      container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('createFromName("Idea") creates Idea.md in root', () async {
      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName('Idea');

      expect(path.value, 'Idea.md');
      final stat = await fs.stat(path);
      expect(stat, isNotNull);
    });

    test('newFileLocation: folder / Inbox creates Inbox/Idea.md', () async {
      container
          .read(vaultSettingsProvider.notifier)
          .update(
            (s) =>
                s.copyWith(newFileLocation: 'folder', newFileFolder: 'Inbox'),
          );

      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName('Idea');

      expect(path.value, 'Inbox/Idea.md');
      final stat = await fs.stat(path);
      expect(stat, isNotNull);
    });

    test('current location with context A/B.md creates A/Idea.md', () async {
      container
          .read(vaultSettingsProvider.notifier)
          .update((s) => s.copyWith(newFileLocation: 'current'));

      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName(
        'Idea',
        contextNote: VaultPath('A/B.md'),
      );

      expect(path.value, 'A/Idea.md');
      final stat = await fs.stat(path);
      expect(stat, isNotNull);
    });

    test('Projects/Plan creates Projects/Plan.md', () async {
      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName('Projects/Plan');

      expect(path.value, 'Projects/Plan.md');
      final stat = await fs.stat(path);
      expect(stat, isNotNull);
    });

    test('name ending in .md is not doubled', () async {
      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName('Doc.md');

      expect(path.value, 'Doc.md');
    });

    test('invalid name throws InvalidPathException', () async {
      final creator = container.read(noteCreatorProvider);
      expect(
        () => creator.createFromName('a:b'),
        throwsA(isA<InvalidPathException>()),
      );
    });

    test('existing file returned without rewriting', () async {
      await fs.writeText(
        VaultPath('Existing.md'),
        const TextDocument(text: 'Original content'),
      );
      final writeCountBefore = fs.writeCount;

      final creator = container.read(noteCreatorProvider);
      final path = await creator.createFromName('Existing');

      expect(path.value, 'Existing.md');
      expect(fs.writeCount, writeCountBefore);
      final text = await fs.readText(path);
      expect(text.text, 'Original content');
    });

    test(
      'createUntitled generates Untitled.md, Untitled 1.md, Untitled 2.md',
      () async {
        final creator = container.read(noteCreatorProvider);
        final p1 = await creator.createUntitled();
        final p2 = await creator.createUntitled();
        final p3 = await creator.createUntitled();

        expect(p1.value, 'Untitled.md');
        expect(p2.value, 'Untitled 1.md');
        expect(p3.value, 'Untitled 2.md');
      },
    );
  });
}

final class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this._initialSession);
  final VaultSession _initialSession;

  @override
  VaultSession? build() => _initialSession;
}
