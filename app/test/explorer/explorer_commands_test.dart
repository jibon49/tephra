// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/explorer/explorer_commands.dart';
import 'package:tephra/explorer/explorer_state.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

class TestVaultSessionNotifier extends VaultSessionNotifier {
  TestVaultSessionNotifier(this.initialSession);
  final VaultSession initialSession;

  @override
  VaultSession? build() => initialSession;
}

void main() {
  group('explorer_commands_test', () {
    late CommandRegistry registry;
    late MemoryVaultFileSystem fs;
    late VaultSession session;

    setUp(() {
      registry = CommandRegistry();
      registerExplorerCommands(registry);

      fs = MemoryVaultFileSystem();
      session = VaultSession(
        vaultId: 'v1',
        rootDir: '/vault',
        name: 'test-vault',
        fs: fs,
        settings: const VaultSettings(),
      );
    });

    test('all 7 commands are registered with expected default shortcuts', () {
      final cmdRename = registry.byId('note.rename-note');
      expect(cmdRename, isNotNull);
      expect(
        cmdRename!.defaultShortcuts,
        equals([const SingleActivator(LogicalKeyboardKey.f2)]),
      );

      expect(registry.byId('note.create-folder'), isNotNull);
      expect(registry.byId('note.delete-note'), isNotNull);
      expect(registry.byId('note.duplicate-note'), isNotNull);
      expect(registry.byId('note.reveal-in-explorer'), isNotNull);
      expect(registry.byId('explorer.collapse-all'), isNotNull);
      expect(registry.byId('explorer.reveal-active-file'), isNotNull);
    });

    testWidgets(
      'note.reveal-in-explorer is unavailable without an active note',
      (tester) async {
        late WidgetRef capturedRef;
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
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        final cmd = registry.byId('note.reveal-in-explorer')!;
        expect(capturedRef.read(activeNotePathProvider), isNull);
        expect(cmd.isAvailable?.call(capturedRef), isFalse);
      },
    );

    testWidgets(
      'explorer.reveal-active-file expands ancestors and selects active file',
      (tester) async {
        await fs.createFolder(VaultPath('A'));
        await fs.createFolder(VaultPath('A/B'));
        await fs.writeText(
          VaultPath('A/B/DeepNote.md'),
          const TextDocument(text: 'deep'),
        );

        late WidgetRef capturedRef;
        late BuildContext capturedContext;
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
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  capturedContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        capturedRef
            .read(workspaceProvider.notifier)
            .openPath(VaultPath('A/B/DeepNote.md'));
        await tester.pump();
        expect(
          capturedRef.read(activeNotePathProvider),
          equals(VaultPath('A/B/DeepNote.md')),
        );

        final cmd = registry.byId('explorer.reveal-active-file')!;
        expect(cmd.isAvailable?.call(capturedRef), isTrue);

        cmd.run(capturedRef, capturedContext);
        await tester.pump();

        final expanded = capturedRef.read(explorerExpandedProvider);
        expect(expanded.contains(VaultPath('A')), isTrue);
        expect(expanded.contains(VaultPath('A/B')), isTrue);
        expect(
          capturedRef.read(explorerSelectedProvider),
          equals(VaultPath('A/B/DeepNote.md')),
        );
      },
    );
  });
}
