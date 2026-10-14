// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_registry.dart';
import 'package:tephra/editor/providers.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/links/backlinks_pane.dart';
import 'package:tephra/links/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  testWidgets(
    'BacklinksPane displays linked mentions and queries unlinked only when expanded',
    (tester) async {
      final target = VaultPath('Target.md');
      final sourceA = VaultPath('SourceA.md');
      final sourceB = VaultPath('SourceB.md');

      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        sourceA,
        const TextDocument(text: 'Hello [[Target]] world'),
      );
      await fs.writeText(
        sourceB,
        const TextDocument(text: 'Other [[Target]] note'),
      );

      final links = <LinkRecord>[
        LinkRecord(
          source: sourceA,
          targetRaw: 'Target',
          targetPath: target,
          start: 6,
          end: 16,
          line: 0,
          kind: LinkKind.link,
          syntax: LinkSyntax.wiki,
          resolved: true,
          viaAlias: false,
        ),
        LinkRecord(
          source: sourceB,
          targetRaw: 'Target',
          targetPath: target,
          start: 6,
          end: 16,
          line: 0,
          kind: LinkKind.link,
          syntax: LinkSyntax.wiki,
          resolved: true,
          viaAlias: false,
        ),
      ];

      var unlinkedCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeNotePathProvider.overrideWithValue(target),
            vaultFsProvider.overrideWithValue(fs),
            editorRegistryProvider.overrideWithValue(EditorRegistry()),
            backlinksProvider(target).overrideWith((ref) async => links),
            unlinkedMentionsProvider(target).overrideWith((ref) async {
              unlinkedCalls++;
              return [
                UnlinkedMention(
                  source: sourceA,
                  start: 0,
                  end: 5,
                  line: 0,
                  matchedText: 'Hello',
                  snippet: 'Hello [[Target]] world',
                  snippetStart: 0,
                  snippetEnd: 5,
                ),
              ];
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BacklinksPane()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Two group headers exist
      expect(find.text('SourceA'), findsOneWidget);
      expect(find.text('SourceB'), findsOneWidget);

      // 2. Linked context contains the bold link
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Hello [[Target]] world'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Other [[Target]] note'),
        ),
        findsOneWidget,
      );

      // 3. Unlinked mentions section is collapsed, so unlinkedMentions was not called
      expect(unlinkedCalls, equals(0));

      // 4. Tap the unlinked section header to expand
      await tester.tap(find.text('Unlinked mentions'));
      await tester.pumpAndSettle();

      // 5. Unlinked mentions were queried
      expect(unlinkedCalls, greaterThan(0));
      expect(find.text('Link'), findsOneWidget);
    },
  );
}
