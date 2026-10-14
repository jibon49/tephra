// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra/workspace/unsupported_file_view.dart';
import 'package:tephra/workspace/view_kind.dart';
import 'package:tephra/workspace/view_registry.dart';
import 'package:tephra_core/tephra_core.dart';

import '../helpers/test_app.dart';

void main() {
  group('viewKindFor', () {
    test('classifies extensions correctly', () {
      expect(viewKindFor(VaultPath('a.md')), equals(ViewKind.markdown));
      expect(viewKindFor(VaultPath('A.MD')), equals(ViewKind.markdown));
      expect(viewKindFor(VaultPath('x.canvas')), equals(ViewKind.canvas));
      expect(viewKindFor(VaultPath('x.base')), equals(ViewKind.base));
      expect(viewKindFor(VaultPath('doc.pdf')), equals(ViewKind.pdf));
      expect(viewKindFor(VaultPath('p.PNG')), equals(ViewKind.image));
      expect(viewKindFor(VaultPath('s.svg')), equals(ViewKind.image));
      expect(viewKindFor(VaultPath('song.mp3')), equals(ViewKind.audio));
      expect(viewKindFor(VaultPath('clip.webm')), equals(ViewKind.video));
      expect(viewKindFor(VaultPath('file.xyz')), equals(ViewKind.unsupported));
      expect(viewKindFor(VaultPath('noext')), equals(ViewKind.unsupported));
    });
  });

  group('ViewRegistry', () {
    testWidgets('titleFor returns stem for markdown and name for others', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final registry = ViewRegistry();
      expect(
        registry.titleFor(FileTabContent(VaultPath('a/Note.md')), l10n),
        equals('Note'),
      );
      expect(
        registry.titleFor(FileTabContent(VaultPath('img.png')), l10n),
        equals('img.png'),
      );
    });

    testWidgets('unknown extension builds UnsupportedFileView', (tester) async {
      final registry = ViewRegistry();
      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              return registry.build(
                context,
                ref,
                FileTabContent(VaultPath('archive.zip')),
                'tab-1',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnsupportedFileView), findsOneWidget);
      expect(find.text('archive.zip'), findsOneWidget);
    });

    testWidgets('a later register for md replaces the builder', (tester) async {
      final registry = ViewRegistry();
      registry.register(
        ViewRegistration(
          id: 'custom-md',
          extensions: const {'md'},
          builder: (context, ref, content, tabId) =>
              const Text('Custom Markdown View'),
          icon: Icons.edit,
        ),
      );

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              return registry.build(
                context,
                ref,
                FileTabContent(VaultPath('test.md')),
                'tab-1',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Markdown View'), findsOneWidget);
    });
  });
}
