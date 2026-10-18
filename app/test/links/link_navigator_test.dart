// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/links/link_navigator.dart';
import 'package:tephra/reading/link_actions.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

class FakeNoteIndexNotifier extends NoteIndexNotifier {
  FakeNoteIndexNotifier(this.index);
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

  group('LinkNavigator', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late ProviderContainer container;
    late LinkNavigator navigator;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('Existing.md'),
        const TextDocument(
          text: '# Main\n\nSome text\n\n# Section\n\nMore text',
        ),
      );

      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();

      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(newFileLocation: 'root'),
      );

      container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          vaultFsProvider.overrideWithValue(fs),
          noteIndexProvider.overrideWith(() => FakeNoteIndexNotifier(index)),
        ],
      );

      navigator = container.read(linkNavigatorProvider);
    });

    tearDown(() async {
      container.dispose();
      await index.close();
    });

    test('resolved target opens that path', () async {
      await navigator.open(from: VaultPath('from.md'), target: 'Existing');

      final tab = container.read(workspaceProvider).focusedTab;
      expect(tab, isNotNull);
      expect(tab!.content, isA<FileTabContent>());
      expect(
        (tab.content as FileTabContent).path,
        equals(VaultPath('Existing.md')),
      );
    });

    test('heading reveals the heading offset', () async {
      await navigator.open(
        from: VaultPath('from.md'),
        target: 'Existing',
        heading: 'Section',
      );

      final tab = container.read(workspaceProvider).focusedTab;
      expect(tab, isNotNull);
      expect(
        (tab!.content as FileTabContent).path,
        equals(VaultPath('Existing.md')),
      );

      final jump = container.read(pendingJumpProvider);
      expect(jump, isNotNull);
      expect(jump!.path, equals(VaultPath('Existing.md')));
      expect(jump.heading, equals('Section'));
      expect(jump.offset, equals(19));
    });

    test('unresolved New Idea with new-note location vault root creates New Idea.md and opens it', () async {
      await navigator.open(from: VaultPath('from.md'), target: 'New Idea');

      final stat = await fs.stat(VaultPath('New Idea.md'));
      expect(stat, isNotNull);

      final tab = container.read(workspaceProvider).focusedTab;
      expect(tab, isNotNull);
      expect(
        (tab!.content as FileTabContent).path,
        equals(VaultPath('New Idea.md')),
      );
    });

    test('unresolved Projects/Plan creates Projects/Plan.md', () async {
      await navigator.open(from: VaultPath('from.md'), target: 'Projects/Plan');

      final stat = await fs.stat(VaultPath('Projects/Plan.md'));
      expect(stat, isNotNull);

      final tab = container.read(workspaceProvider).focusedTab;
      expect(tab, isNotNull);
      expect(
        (tab!.content as FileTabContent).path,
        equals(VaultPath('Projects/Plan.md')),
      );
    });

    test(
      'unresolved pic.png creates nothing and shows linkTargetFileMissing',
      () async {
        await navigator.open(from: VaultPath('from.md'), target: 'pic.png');

        final stat = await fs.stat(VaultPath('pic.png'));
        expect(stat, isNull);
        final statMd = await fs.stat(VaultPath('pic.png.md'));
        expect(statMd, isNull);

        final tab = container.read(workspaceProvider).focusedTab;
        expect(tab, isNull);
      },
    );
  });
}
