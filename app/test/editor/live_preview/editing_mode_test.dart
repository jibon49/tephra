// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/builtin_commands.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/editor/editor_controller.dart';
import 'package:tephra/editor/editor_options.dart';
import 'package:tephra/editor/live_preview/editing_mode.dart';
import 'package:tephra/editor/live_preview/live_preview_session.dart';
import 'package:tephra/reading/parse_service.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_document.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra/workspace/workspace_persistence.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../helpers/fake_editor_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Editing mode command registry', () {
    test('Ctrl+Shift+E registers editor.toggle-editing-mode, Ctrl+E stays reading view', () {
      final registry = CommandRegistry();
      registerBuiltinCommands(registry);

      final toggleEditing = registry.byId('editor.toggle-editing-mode');
      expect(toggleEditing, isNotNull);
      expect(toggleEditing!.showInMobileToolbar, isFalse);
      expect(toggleEditing.defaultShortcuts.length, equals(1));
      expect(
        toggleEditing.defaultShortcuts.first,
        equals(
          const SingleActivator(
            LogicalKeyboardKey.keyE,
            control: true,
            shift: true,
          ),
        ),
      );

      final toggleReading = registry.byId('editor.toggle-reading-view');
      expect(toggleReading, isNotNull);
      expect(toggleReading!.defaultShortcuts.length, equals(1));
      expect(
        toggleReading.defaultShortcuts.first,
        equals(const SingleActivator(LogicalKeyboardKey.keyE, control: true)),
      );
    });
  });

  group('EditorDecorator toggle', () {
    test('toggle sets setDecorator(null) and back', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('Test.md'),
        const TextDocument(text: 'Hello **world**'),
      );
      final doc = NoteDocument(
        fs: fs,
        path: VaultPath('Test.md'),
        clock: const SystemClock(),
        parseService: const ParseService(),
      );
      await doc.load();
      final engine = FakeEditorEngine('Hello **world**');
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: const EditorOptions(),
        parseService: const ParseService(),
      );

      final session = LivePreviewSession(target: controller);
      expect(controller.decorator, isNull);

      // Set Live Preview decorator
      controller.setDecorator(session.decorator);
      expect(controller.decorator, equals(session.decorator));
      expect(engine.decorator, equals(session.decorator));

      // Toggle to Source mode (null)
      controller.setDecorator(null);
      expect(controller.decorator, isNull);
      expect(engine.decorator, isNull);

      // Toggle back to Live Preview decorator
      controller.setDecorator(session.decorator);
      expect(controller.decorator, equals(session.decorator));
      expect(engine.decorator, equals(session.decorator));

      session.dispose();
      controller.dispose();
    });
  });

  group('New tab defaultEditingMode', () {
    test(
      'new tab uses defaultEditingMode setting (livePreview default)',
      () async {
        final fs = MemoryVaultFileSystem();
        await fs.writeText(VaultPath('A.md'), const TextDocument(text: '# A'));
        await fs.writeText(VaultPath('B.md'), const TextDocument(text: '# B'));

        final container = ProviderContainer(
          overrides: [
            initialAppSettingsProvider.overrideWithValue(
              const AppSettings(deviceId: 'test-device'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(vaultSessionProvider.notifier)
            .set(
              VaultSession(
                vaultId: 'v1',
                rootDir: '/vault',
                name: 'V',
                fs: fs,
                settings: const VaultSettings(
                  editor: {'defaultEditingMode': 'livePreview'},
                ),
              ),
            );

        final notifier = container.read(workspaceProvider.notifier);
        notifier.openPath(VaultPath('A.md'));

        var tab = container.read(workspaceProvider).focusedTab;
        expect(tab, isNotNull);
        var content = tab!.content as FileTabContent;
        expect(content.editingMode, equals(EditingMode.livePreview));

        // Now change vault settings to source default
        await container
            .read(vaultSessionProvider.notifier)
            .set(
              VaultSession(
                vaultId: 'v1',
                rootDir: '/vault',
                name: 'V',
                fs: fs,
                settings: const VaultSettings(
                  editor: {'defaultEditingMode': 'source'},
                ),
              ),
            );

        notifier.openPath(VaultPath('B.md'), newTab: true);

        tab = container.read(workspaceProvider).focusedTab;
        expect(tab, isNotNull);
        content = tab!.content as FileTabContent;
        expect(content.editingMode, equals(EditingMode.source));
      },
    );

    test('toggleEditingMode in reading view switches to editing view in current editingMode', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Text'),
      );

      final container = ProviderContainer(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(deviceId: 'test-device'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(vaultSessionProvider.notifier)
          .set(
            VaultSession(
              vaultId: 'v1',
              rootDir: '/vault',
              name: 'V',
              fs: fs,
              settings: const VaultSettings(
                editor: {'defaultEditingMode': 'livePreview'},
              ),
            ),
          );

      final notifier = container.read(workspaceProvider.notifier);
      notifier.openPath(VaultPath('Note.md'));

      // Switch to reading mode
      notifier.setMode(
        container.read(workspaceProvider).focusedTab!.id,
        ViewMode.reading,
      );
      expect(
        container.read(workspaceProvider).focusedTab!.mode,
        equals(ViewMode.reading),
      );

      // Calling toggleEditingMode while in reading view switches back to editing (source ViewMode)
      notifier.toggleEditingMode();
      var tab = container.read(workspaceProvider).focusedTab!;
      expect(tab.mode, equals(ViewMode.source));
      var content = tab.content as FileTabContent;
      expect(content.editingMode, equals(EditingMode.livePreview));

      // Calling toggleEditingMode while in editing view flips editingMode
      notifier.toggleEditingMode();
      tab = container.read(workspaceProvider).focusedTab!;
      expect(tab.mode, equals(ViewMode.source));
      content = tab.content as FileTabContent;
      expect(content.editingMode, equals(EditingMode.source));
    });
  });

  group('workspace.json mode persistence', () {
    test('mode persisted into workspace.json of this device only; other device byte-identical; unknown keys preserved', () async {
      final fs = MemoryVaultFileSystem();
      const store = TephraJsonStore();
      final persistence = WorkspacePersistence();

      final otherDeviceJson = {
        'axis': 'vertical',
        'focused': 0,
        'customExtraField': {'keep': true},
      };

      await store.writeMap(fs, VaultPath('.tephra/workspace.json'), {
        'device-other': otherDeviceJson,
      });

      final state = WorkspaceState(
        panes: [
          PaneState(
            id: 'pane-1',
            tabs: [
              TabState(
                id: 'tab-1',
                history: [
                  FileTabContent(
                    VaultPath('Note.md'),
                    editingMode: EditingMode.livePreview,
                  ),
                ],
                historyIndex: 0,
                mode: ViewMode.source,
              ),
            ],
            activeIndex: 0,
          ),
        ],
        axis: SplitAxis.horizontal,
      );

      await persistence.save(
        fs: fs,
        deviceId: 'device-my',
        state: state,
        recentFiles: [VaultPath('Note.md')],
      );

      final map = await store.readMap(fs, VaultPath('.tephra/workspace.json'));
      expect(map.containsKey('device-other'), isTrue);
      expect(map['device-other'], equals(otherDeviceJson));

      final myDevice = map['device-my']! as Map<String, Object?>;
      final panes = myDevice['panes']! as List<Object?>;
      final pane0 = panes[0]! as Map<String, Object?>;
      final tabs = pane0['tabs']! as List<Object?>;
      final tab0 = tabs[0]! as Map<String, Object?>;
      final history = tab0['history']! as List<Object?>;
      final h0 = history[0]! as Map<String, Object?>;
      expect(h0['mode'], equals('livePreview'));

      // Now restore
      await fs.writeText(
        VaultPath('Note.md'),
        const TextDocument(text: 'Note text'),
      );
      final restored = await persistence.restore(fs: fs, deviceId: 'device-my');
      expect(restored, isNotNull);
      final restoredTab = restored!.state.panes[0].tabs[0];
      final restoredContent = restoredTab.content as FileTabContent;
      expect(restoredContent.editingMode, equals(EditingMode.livePreview));
    });
  });
}
