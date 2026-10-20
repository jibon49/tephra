// © 2026 Tephra. All rights reserved.

@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/theme/app_theme.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  late MemoryVaultFileSystem fs;
  late VaultSession session;
  final syntaxDir = Directory('../test_vaults/syntax').existsSync()
      ? Directory('../test_vaults/syntax')
      : Directory('test_vaults/syntax');

  setUpAll(() async {
    fs = MemoryVaultFileSystem();
    session = VaultSession(
      vaultId: 'syntax-vault',
      rootDir: syntaxDir.absolute.path,
      name: 'syntax',
      fs: fs,
      settings: const VaultSettings(),
    );

    // Populate memory filesystem with files from test_vaults/syntax
    for (final entity in syntaxDir.listSync(recursive: true)) {
      if (entity is File) {
        final rel = entity.path
            .substring(syntaxDir.path.length)
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        final bytes = entity.readAsBytesSync();
        await fs.writeBytes(VaultPath(rel), bytes);
      }
    }
  });

  const goldenKey = ValueKey('golden_root');

  Future<void> testGolden({
    required WidgetTester tester,
    required String relPath,
    required double width,
    required double height,
    required ThemeData theme,
    required String goldenName,
  }) async {
    final file = File(p.join(syntaxDir.path, relPath));
    final text = file.readAsStringSync();

    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device-id'),
          ),
          vaultSessionProvider.overrideWith(
            () => TestVaultSessionNotifier(session),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: RepaintBoundary(
                key: goldenKey,
                child: Material(
                  color: theme.colorScheme.surface,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ReadingView(
                      path: VaultPath(relPath),
                      text: text,
                      readableWidth: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  final syntaxFiles = [
    '01-headings.md',
    '02-paragraphs.md',
    '03-emphasis.md',
    '04-lists.md',
    '05-tasks.md',
    '06-blockquotes.md',
    '07-callouts.md',
    '08-code.md',
    '09-tables.md',
    '10-links.md',
    '11-wikilinks.md',
    '12-embeds.md',
    '13-tags.md',
    '14-comments.md',
    '15-block-ids.md',
    '16-math.md',
    '17-footnotes.md',
    '18-frontmatter.md',
    '19-html.md',
    '20-thematic-breaks.md',
    '21-escapes-entities.md',
    '22-mixed.md',
    '23-unicode.md',
    'Folder/Nested Note.md',
  ];

  for (final relPath in syntaxFiles) {
    final baseName = p.basenameWithoutExtension(relPath);
    final safeName = baseName
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();
    final goldenName = 'syntax_$safeName';

    testWidgets('golden $goldenName', (tester) async {
      await testGolden(
        tester: tester,
        relPath: relPath,
        width: 600,
        height: 900,
        theme: AppTheme.light(),
        goldenName: goldenName,
      );
    });
  }

  testWidgets('golden syntax_07_callouts_dark', (tester) async {
    await testGolden(
      tester: tester,
      relPath: '07-callouts.md',
      width: 600,
      height: 900,
      theme: AppTheme.dark(),
      goldenName: 'syntax_07_callouts_dark',
    );
  });

  testWidgets('golden syntax_05_tasks_phone', (tester) async {
    await testGolden(
      tester: tester,
      relPath: '05-tasks.md',
      width: 360,
      height: 900,
      theme: AppTheme.light(),
      goldenName: 'syntax_05_tasks_phone',
    );
  });

  testWidgets('golden syntax_09_tables_phone', (tester) async {
    await testGolden(
      tester: tester,
      relPath: '09-tables.md',
      width: 360,
      height: 900,
      theme: AppTheme.light(),
      goldenName: 'syntax_09_tables_phone',
    );
  });
}
