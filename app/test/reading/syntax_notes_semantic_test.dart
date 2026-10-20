// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/callout_view.dart';
import 'package:tephra/reading/embeds/file_chip.dart';
import 'package:tephra/reading/inline_text.dart';
import 'package:tephra/reading/reading_code.dart';
import 'package:tephra/reading/reading_controller.dart';
import 'package:tephra/reading/reading_footnotes.dart';
import 'package:tephra/reading/reading_scope.dart';
import 'package:tephra/reading/reading_view.dart';
import 'package:tephra/reading/task_checkbox.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
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

  Widget buildHarness({
    required String text,
    required VaultPath path,
    ReadingViewController? controller,
    void Function(WikiLinkTap)? onOpenWikiLink,
  }) {
    return ProviderScope(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(deviceId: 'test-device-id'),
        ),
        vaultSessionProvider.overrideWith(
          () => TestVaultSessionNotifier(session),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReadingView(
            path: path,
            text: text,
            controller: controller,
            onOpenWikiLink: onOpenWikiLink,
          ),
        ),
      ),
    );
  }

  testWidgets('01-headings: 9+ Semantics(header) equal to parse count', (
    tester,
  ) async {
    final file = File(p.join(syntaxDir.path, '01-headings.md'));
    final text = file.readAsStringSync();
    final parsed = MarkdownParser.parse(text);

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('01-headings.md')),
    );
    await tester.pumpAndSettle();

    final headers = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.header == true,
    );
    expect(headers.evaluate().length, equals(parsed.headings.length));
    expect(parsed.headings.length, greaterThanOrEqualTo(9));
  });

  testWidgets('04-lists: • and ordered list markers exist', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final file = File(p.join(syntaxDir.path, '04-lists.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('04-lists.md')),
    );
    await tester.pumpAndSettle();

    expect(find.text('•'), findsWidgets);
    expect(find.text('1.'), findsWidgets);
    expect(find.textContaining('Starts at seven'), findsOneWidget);
  });

  testWidgets('05-tasks: task checkboxes and last line is not a task', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final file = File(p.join(syntaxDir.path, '05-tasks.md'));
    final text = file.readAsStringSync();
    final parsed = MarkdownParser.parse(text);

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('05-tasks.md')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskCheckbox), findsNWidgets(parsed.tasks.length));
    expect(
      find.textContaining('[ ]Not a task', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('07-callouts: CalloutViews match MdCallout parse count', (
    tester,
  ) async {
    final file = File(p.join(syntaxDir.path, '07-callouts.md'));
    final text = file.readAsStringSync();
    final parsed = MarkdownParser.parse(text);

    final allCallouts = <MdCallout>[];
    void collectCallouts(MdNode n) {
      if (n is MdCallout) allCallouts.add(n);
      for (final c in n.children) {
        collectCallouts(c);
      }
    }

    collectCallouts(parsed.root);

    final topLevelCallouts = parsed.root.children
        .whereType<MdCallout>()
        .toList();
    final controller = ReadingViewController();

    await tester.pumpWidget(
      buildHarness(
        text: text,
        path: VaultPath('07-callouts.md'),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    final foundCalloutKeys = <Key>{};
    for (final node in topLevelCallouts) {
      controller.scrollToOffset(node.start);
      await tester.pumpAndSettle();
      for (final element in find.byType(CalloutView).evaluate()) {
        final widget = element.widget as CalloutView;
        if (widget.key != null) {
          foundCalloutKeys.add(widget.key!);
        } else {
          foundCalloutKeys.add(Key('callout:${widget.node.start}'));
        }
      }
    }

    expect(foundCalloutKeys.length, equals(allCallouts.length));
  });

  testWidgets('08-code: CodeBlockView count equals parse count', (
    tester,
  ) async {
    final file = File(p.join(syntaxDir.path, '08-code.md'));
    final text = file.readAsStringSync();
    final parsed = MarkdownParser.parse(text);
    final codeBlockCount = parsed.root.children.whereType<MdCodeBlock>().length;

    final controller = ReadingViewController();
    await tester.pumpWidget(
      buildHarness(
        text: text,
        path: VaultPath('08-code.md'),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    final foundCodeKeys = <Key>{};
    for (final node in parsed.root.children.whereType<MdCodeBlock>()) {
      controller.scrollToOffset(node.start);
      await tester.pumpAndSettle();
      for (final element in find.byType(CodeBlockView).evaluate()) {
        final widget = element.widget as CodeBlockView;
        foundCodeKeys.add(Key('code:${widget.node.start}'));
      }
    }
    expect(foundCodeKeys.length, equals(codeBlockCount));
  });

  testWidgets('09-tables: a Table exists', (tester) async {
    final file = File(p.join(syntaxDir.path, '09-tables.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('09-tables.md')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsWidgets);
  });

  testWidgets(
    '10-links and 11-wikilinks: wikilink tap triggers callback with target',
    (tester) async {
      final file = File(p.join(syntaxDir.path, '11-wikilinks.md'));
      final text = file.readAsStringSync();
      WikiLinkTap? tappedLink;

      await tester.pumpWidget(
        buildHarness(
          text: text,
          path: VaultPath('11-wikilinks.md'),
          onOpenWikiLink: (tap) => tappedLink = tap,
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(InlineText),
              matching: find.byType(Text),
            )
            .first,
      );
      final span = textWidget.textSpan! as TextSpan;
      final wikiSpan = span.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == '01-headings',
      );
      final recognizer = wikiSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap?.call();

      expect(tappedLink, isNotNull);
      expect(tappedLink!.target, equals('01-headings'));
    },
  );

  testWidgets('12-embeds: FileChip exists for non-image attachments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final file = File(p.join(syntaxDir.path, '12-embeds.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('12-embeds.md')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FileChip), findsWidgets);
  });

  testWidgets('13-tags: tag text found', (tester) async {
    final file = File(p.join(syntaxDir.path, '13-tags.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('13-tags.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('#nested/tag'), findsOneWidget);
  });

  testWidgets('14-comments: comment text not found in widget tree', (
    tester,
  ) async {
    final file = File(p.join(syntaxDir.path, '14-comments.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('14-comments.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('inline comment'), findsNothing);
    expect(find.textContaining('Multi-line comment'), findsNothing);
  });

  testWidgets('16-math: math text found', (tester) async {
    final file = File(p.join(syntaxDir.path, '16-math.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('16-math.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('x^2'), findsWidgets);
  });

  testWidgets('17-footnotes: footnote section present', (tester) async {
    final file = File(p.join(syntaxDir.path, '17-footnotes.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('17-footnotes.md')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FootnoteSectionView), findsOneWidget);
  });

  testWidgets('18-frontmatter: frontmatter key text not found', (tester) async {
    final file = File(p.join(syntaxDir.path, '18-frontmatter.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('18-frontmatter.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Frontmatter types'), findsNothing);
    expect(find.textContaining('Plain text value'), findsNothing);
    expect(find.textContaining('Body after frontmatter'), findsOneWidget);
  });

  testWidgets('19-html: raw div text shown', (tester) async {
    final file = File(p.join(syntaxDir.path, '19-html.md'));
    final text = file.readAsStringSync();

    await tester.pumpWidget(
      buildHarness(text: text, path: VaultPath('19-html.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('<div class="note">'), findsOneWidget);
  });

  testWidgets('all 24 syntax notes pump without exception', (tester) async {
    final mdFiles = syntaxDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    expect(mdFiles.length, equals(24));

    for (final file in mdFiles) {
      final text = file.readAsStringSync();
      final rel = file.path
          .substring(syntaxDir.path.length)
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'^/'), '');

      await tester.pumpWidget(buildHarness(text: text, path: VaultPath(rel)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed pumping $rel');
    }
  });
}
