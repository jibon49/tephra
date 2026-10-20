// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/file_chip.dart';
import 'package:tephra/reading/reading_images.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
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
  late List<int> samplePngBytes;

  setUpAll(() {
    final sampleFile = File(
      Directory('test_vaults').existsSync()
          ? 'test_vaults/syntax/attachments/sample.png'
          : '../test_vaults/syntax/attachments/sample.png',
    );
    if (sampleFile.existsSync()) {
      samplePngBytes = sampleFile.readAsBytesSync();
    } else {
      samplePngBytes = const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]; // Minimal PNG header
    }
  });

  setUp(() async {
    fs = MemoryVaultFileSystem();
    session = VaultSession(
      vaultId: 'v1',
      rootDir: '/vault',
      name: 'Test',
      fs: fs,
      settings: const VaultSettings(),
    );
    await fs.writeBytes(VaultPath('sample.png'), samplePngBytes);
    await fs.writeBytes(VaultPath('sample.pdf'), const [
      0x25,
      0x50,
      0x44,
      0x46,
    ]);
    await fs.writeText(
      VaultPath('Folder/Nested Note.md'),
      const TextDocument(text: '# Note'),
    );
  });

  Widget buildHarness({required Widget child}) {
    return ProviderScope(
      overrides: [
        vaultSessionProvider.overrideWith(
          () => TestVaultSessionNotifier(session),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('sample.png renders Image.memory via VaultImageView', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(child: VaultImageView(path: VaultPath('sample.png'))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('![alt|120x80](sample.png) renders SizedBox 120x80 and alt', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        child: ReadingMarkdownImage(
          url: 'sample.png',
          alt: 'alt|120x80',
          from: VaultPath('note.md'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 120 && w.height == 80,
      ),
    );
    expect(sizedBox.width, equals(120));
    expect(sizedBox.height, equals(80));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.semanticLabel, equals('alt'));
  });

  testWidgets('missing image renders placeholder chip', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        child: ReadingMarkdownImage(
          url: 'missing.png',
          alt: 'Missing Pic',
          from: VaultPath('note.md'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('missing.png'), findsOneWidget);
  });

  testWidgets('![[sample.pdf]] renders FileChip named sample.pdf', (
    tester,
  ) async {
    final node = MdWikiLink(0, 15, target: 'sample.pdf', embed: true);

    await tester.pumpWidget(
      buildHarness(
        child: ReadingWikiEmbed(node: node, from: VaultPath('note.md')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FileChip), findsOneWidget);
    expect(find.text('sample.pdf'), findsOneWidget);
  });

  testWidgets('![[sample.png|50]] sets width 50', (tester) async {
    final node = MdWikiLink(
      0,
      17,
      target: 'sample.png',
      size: const EmbedSize(50),
      embed: true,
    );

    await tester.pumpWidget(
      buildHarness(
        child: ReadingWikiEmbed(node: node, from: VaultPath('note.md')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 50),
    );
    expect(sizedBox.width, equals(50));
  });

  testWidgets('![[Folder/Nested Note]] renders EmbeddedNoteBox', (
    tester,
  ) async {
    final node = MdWikiLink(0, 25, target: 'Folder/Nested Note', embed: true);

    await tester.pumpWidget(
      buildHarness(
        child: ReadingWikiEmbed(node: node, from: VaultPath('note.md')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmbeddedNoteBox), findsOneWidget);
    expect(find.text('Nested Note'), findsOneWidget);
  });

  testWidgets('http image URL renders Image.network', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        child: ReadingMarkdownImage(
          url: 'https://example.com/pic.png',
          alt: 'Network Pic',
          from: VaultPath('note.md'),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<NetworkImage>());
  });
}
