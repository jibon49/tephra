// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/reading/link_actions.dart';
import 'package:tephra/reading/reading_controller.dart';
import 'package:tephra/reading/reading_scope.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class FakeUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
}

class TestReadingController extends ReadingViewController {
  String? scrolledHeading;
  String? scrolledBlockRef;

  @override
  void scrollToHeading(String heading) {
    scrolledHeading = heading;
  }

  @override
  void scrollToBlockRef(String blockRef) {
    scrolledBlockRef = blockRef;
  }
}

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  late FakeUrlLauncher fakeLauncher;
  late MemoryVaultFileSystem fs;
  late VaultSession session;

  setUp(() {
    fakeLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
    fs = MemoryVaultFileSystem();
    session = VaultSession(
      vaultId: 'v1',
      rootDir: '/vault',
      name: 'Test',
      fs: fs,
      settings: const VaultSettings(),
    );
  });

  Widget buildHarness({
    required Widget Function(BuildContext context, WidgetRef ref) builder,
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
          body: Consumer(builder: (context, ref, _) => builder(context, ref)),
        ),
      ),
    );
  }

  testWidgets('external https:// launches via UrlLauncher', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        builder: (context, ref) {
          final actions = LinkActions(
            ref: ref,
            context: context,
            from: VaultPath('from.md'),
          );
          return ElevatedButton(
            onPressed: () => actions.openMarkdownLink('https://example.com'),
            child: const Text('Open'),
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(fakeLauncher.launchedUrl, equals('https://example.com'));
  });

  testWidgets('mailto: is allowed to launch', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        builder: (context, ref) {
          final actions = LinkActions(
            ref: ref,
            context: context,
            from: VaultPath('from.md'),
          );
          return ElevatedButton(
            onPressed: () =>
                actions.openMarkdownLink('mailto:user@example.com'),
            child: const Text('Mail'),
          );
        },
      ),
    );

    await tester.tap(find.text('Mail'));
    await tester.pumpAndSettle();
    expect(fakeLauncher.launchedUrl, equals('mailto:user@example.com'));
  });

  testWidgets(
    'blocked schemes (javascript, file) show SnackBar and do not launch',
    (tester) async {
      await tester.pumpWidget(
        buildHarness(
          builder: (context, ref) {
            final actions = LinkActions(
              ref: ref,
              context: context,
              from: VaultPath('from.md'),
            );
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () =>
                      actions.openMarkdownLink('javascript:alert(1)'),
                  child: const Text('JS'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      actions.openMarkdownLink('file:///c:/secret.txt'),
                  child: const Text('File'),
                ),
              ],
            );
          },
        ),
      );

      await tester.tap(find.text('JS'));
      await tester.pumpAndSettle();
      expect(fakeLauncher.launchedUrl, isNull);
      expect(find.byType(SnackBar), findsOneWidget);

      // Dismiss snackbar
      ScaffoldMessenger.of(tester.element(find.text('JS')))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(fakeLauncher.launchedUrl, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('relative a%20b.md#Head resolves and sets pending jump', (
    tester,
  ) async {
    await fs.writeText(
      VaultPath('a b.md'),
      const TextDocument(text: '# Head\nContent'),
    );
    PendingJump? consumedJump;

    await tester.pumpWidget(
      buildHarness(
        builder: (context, ref) {
          final actions = LinkActions(
            ref: ref,
            context: context,
            from: VaultPath('from.md'),
          );
          return ElevatedButton(
            onPressed: () async {
              await actions.openMarkdownLink('a%20b.md#Head');
              consumedJump = ref
                  .read(pendingJumpProvider.notifier)
                  .consume(VaultPath('a b.md'));
            },
            child: const Text('Jump'),
          );
        },
      ),
    );

    await tester.tap(find.text('Jump'));
    await tester.pumpAndSettle();
    expect(consumedJump, isNotNull);
    expect(consumedJump!.path, equals(VaultPath('a b.md')));
    expect(consumedJump!.heading, equals('Head'));
  });

  testWidgets('same note #Heading scrolls the current view', (tester) async {
    final testController = TestReadingController();

    await tester.pumpWidget(
      buildHarness(
        builder: (context, ref) {
          final actions = LinkActions(
            ref: ref,
            context: context,
            from: VaultPath('from.md'),
            controller: testController,
          );
          return ElevatedButton(
            onPressed: () => actions.openWikiLink(
              const WikiLinkTap(target: '', heading: 'MySection'),
            ),
            child: const Text('Scroll'),
          );
        },
      ),
    );

    await tester.tap(find.text('Scroll'));
    await tester.pumpAndSettle();
    expect(testController.scrolledHeading, equals('MySection'));
  });

  testWidgets(
    'unresolved wikilink shows SnackBar with Create action which creates the note',
    (tester) async {
      VaultPath? activePath;

      await tester.pumpWidget(
        buildHarness(
          builder: (context, ref) {
            activePath = ref.watch(activeNotePathProvider);
            final actions = LinkActions(
              ref: ref,
              context: context,
              from: VaultPath('from.md'),
            );
            return ElevatedButton(
              onPressed: () => actions.openWikiLink(
                const WikiLinkTap(target: 'New Missing Note'),
              ),
              child: const Text('Resolve'),
            );
          },
        ),
      );

      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(await fs.stat(VaultPath('New Missing Note.md')), isNotNull);
      expect(activePath, equals(VaultPath('New Missing Note.md')));
    },
  );
}
