// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/embeds/embed_context.dart';
import 'package:tephra/reading/embeds/embed_view.dart';
import 'package:tephra/reading/embeds/file_chip.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
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

  group('EmbedView', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late VaultSession session;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('A.md'),
        const TextDocument(text: 'Note A\n\n![[B]]'),
      );
      await fs.writeText(
        VaultPath('B.md'),
        const TextDocument(text: 'Note B\n\n![[A]]'),
      );

      // Chain of 7 notes: N0 -> N1 -> N2 -> N3 -> N4 -> N5 -> N6
      for (var i = 0; i < 7; i++) {
        final next = i + 1 < 7 ? '\n\n![[N${i + 1}]]' : '';
        await fs.writeText(
          VaultPath('N$i.md'),
          TextDocument(text: 'Note N$i$next'),
        );
      }

      await fs.writeBytes(VaultPath('pic.png'), [0x89, 0x50, 0x4E, 0x47]);
      await fs.writeBytes(VaultPath('song.mp3'), [0x49, 0x44, 0x33]);

      index = await NoteIndex.open(':memory:', fs);
      await index.reconcile();

      session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: fs,
        settings: const VaultSettings(),
      );
    });

    tearDown(() async {
      await index.close();
    });

    Widget buildHarness({required Widget child, VaultPath? rootPath}) {
      final path = rootPath ?? VaultPath('A.md');
      return ProviderScope(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmbedContext(depth: 0, chain: {path}, child: child),
          ),
        ),
      );
    }

    testWidgets(
      'note A embeds B embeds A: B renders once, inner A shows embedCircular',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            rootPath: VaultPath('A.md'),
            child: EmbedView.wiki(
              node: MdWikiLink(0, 7, target: 'B', embed: true),
              from: VaultPath('A.md'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Note B'), findsOneWidget);
        expect(find.text('Circular embed'), findsOneWidget);
      },
    );

    testWidgets(
      'chain of 7 notes each embedding the next: 6th level shows embedTooDeep',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            rootPath: VaultPath('N0.md'),
            child: EmbedView.wiki(
              node: MdWikiLink(0, 8, target: 'N1', embed: true),
              from: VaultPath('N0.md'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Embed depth limit reached'), findsOneWidget);
      },
    );

    testWidgets('![[pic.png|120]] renders Image widget with width 120', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          rootPath: VaultPath('note.md'),
          child: EmbedView.wiki(
            node: MdWikiLink(
              0,
              14,
              target: 'pic.png',
              size: EmbedSize(120),
              embed: true,
            ),
            from: VaultPath('note.md'),
          ),
        ),
      );
      await tester.pump();

      final imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      final img = tester.widget<Image>(imgFinder);
      expect(img.width, equals(120.0));
    });

    testWidgets('![[song.mp3]] renders FileChip', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          rootPath: VaultPath('note.md'),
          child: EmbedView.wiki(
            node: MdWikiLink(0, 12, target: 'song.mp3', embed: true),
            from: VaultPath('note.md'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FileChip), findsOneWidget);
      expect(find.text('song.mp3'), findsOneWidget);
    });

    testWidgets(
      'unresolved ![[Nope]] renders not-found box with a Create button',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            rootPath: VaultPath('note.md'),
            child: EmbedView.wiki(
              node: MdWikiLink(0, 8, target: 'Nope', embed: true),
              from: VaultPath('note.md'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Nope'), findsOneWidget);
        expect(find.text('Create'), findsOneWidget);
      },
    );
  });
}
