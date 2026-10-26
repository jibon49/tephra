// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/tephra_command.dart';
import 'package:tephra/core/deep_links/deep_link.dart';
import 'package:tephra/core/deep_links/deep_link_router.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_tools/daily_notes_service.dart';
import 'package:tephra/vault/note_tools/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkRouter', () {
    late ProviderContainer container;
    late CommandRegistry commandRegistry;
    late List<String> commandsRun;
    late List<VaultPath> dailyOpened;
    const currentVaultId = 'vault-current';

    setUp(() {
      commandsRun = [];
      dailyOpened = [];
      commandRegistry = CommandRegistry();

      commandRegistry.register(
        TephraCommand(
          id: 'sticky.new',
          label: (_) => 'New Sticky',
          isAvailable: (_) => true,
          run: (ref, ctx) => commandsRun.add('sticky.new'),
        ),
      );
      commandRegistry.register(
        TephraCommand(
          id: 'sticky.board',
          label: (_) => 'Sticky Board',
          isAvailable: (_) => true,
          run: (ref, ctx) => commandsRun.add('sticky.board'),
        ),
      );

      final fs = MemoryVaultFileSystem();
      final session = VaultSession(
        vaultId: currentVaultId,
        rootDir: '/vault',
        name: 'My Vault',
        fs: fs,
        settings: const VaultSettings(),
      );

      final dailyService = DailyNotesService(
        fs: fs,
        index: () => null,
        getSettings: () => const VaultSettings(),
        clock: const SystemClock(),
        openNote: (path, {newTab = false}) async {
          dailyOpened.add(path);
        },
      );

      container = ProviderContainer(
        overrides: [
          commandRegistryProvider.overrideWithValue(commandRegistry),
          dailyNotesServiceProvider.overrideWithValue(dailyService),
          vaultSessionProvider.overrideWith(
            () => _TestVaultSessionNotifier(session),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('routes OpenNoteLink to workspace openPath', () async {
      final router = container.read(deepLinkRouterProvider);
      final link = OpenNoteLink(path: VaultPath('Notes/Ideas.md'));

      await router.route(link);

      final state = container.read(workspaceProvider);
      expect(state.panes, isNotEmpty);
      final activeTab = state.panes.first.activeTab;
      expect(activeTab, isNotNull);
      expect(
        (activeTab?.content as FileTabContent).path.value,
        equals('Notes/Ideas.md'),
      );
    });

    test('routes NewStickyLink to sticky.new command', () async {
      final router = container.read(deepLinkRouterProvider);
      router.onNewSticky = () => commandsRun.add('sticky.new');
      await router.route(const NewStickyLink());

      expect(commandsRun, contains('sticky.new'));
    });

    test('routes DailyLink to dailyNotesService', () async {
      final router = container.read(deepLinkRouterProvider);
      await router.route(const DailyLink());

      expect(dailyOpened.length, equals(1));
    });

    test('routes BoardLink to sticky.board command', () async {
      final router = container.read(deepLinkRouterProvider);
      router.onOpenBoard = () => commandsRun.add('sticky.board');
      await router.route(const BoardLink());

      expect(commandsRun, contains('sticky.board'));
    });

    test('queues link when vault is closed and flushes when opened', () async {
      final emptyContainer = ProviderContainer(
        overrides: [
          commandRegistryProvider.overrideWithValue(commandRegistry),
          vaultSessionProvider.overrideWith(
            () => _TestVaultSessionNotifier(null),
          ),
        ],
      );

      final router = emptyContainer.read(deepLinkRouterProvider);
      router.init();

      // Route while closed
      await router.route(OpenNoteLink(path: VaultPath('Queued.md')));

      // Check workspace has no open tabs
      expect(emptyContainer.read(workspaceProvider).panes, isEmpty);

      // Open session
      final fs = MemoryVaultFileSystem();
      final session = VaultSession(
        vaultId: currentVaultId,
        rootDir: '/vault',
        name: 'My Vault',
        fs: fs,
        settings: const VaultSettings(),
      );
      await emptyContainer.read(vaultSessionProvider.notifier).set(session);

      // Queued link should flush
      final state = emptyContainer.read(workspaceProvider);
      expect(state.panes, isNotEmpty);
      expect(state.panes.first.tabs.length, equals(1));
      expect(
        (state.panes.first.tabs.first.content as FileTabContent).path.value,
        equals('Queued.md'),
      );

      emptyContainer.dispose();
    });
  });
}

class _TestVaultSessionNotifier extends VaultSessionNotifier {
  _TestVaultSessionNotifier(this._initial);
  final VaultSession? _initial;

  @override
  VaultSession? build() => _initial;
}
