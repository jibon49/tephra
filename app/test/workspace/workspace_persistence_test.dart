// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra/workspace/providers.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra/workspace/workspace_models.dart';
import 'package:tephra/workspace/workspace_persistence.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  late MemoryVaultFileSystem fs;
  late WorkspacePersistence persistence;

  setUp(() {
    fs = MemoryVaultFileSystem();
    persistence = WorkspacePersistence();
  });

  test(
    "save -> JSON has deviceId key and keeps another device's entry untouched",
    () async {
      const store = TephraJsonStore();
      final workspacePath = VaultPath('.tephra/workspace.json');
      await store.writeMap(fs, workspacePath, {
        'device-other': {'axis': 'vertical', 'focused': 1},
      });

      final state = WorkspaceState(
        panes: [
          PaneState(
            id: 'pane-1',
            tabs: [
              TabState(
                id: 'tab-1',
                history: [FileTabContent(VaultPath('Note.md'))],
                historyIndex: 0,
                mode: ViewMode.reading,
              ),
            ],
            activeIndex: 0,
          ),
        ],
        axis: SplitAxis.horizontal,
      );

      await persistence.save(
        fs: fs,
        deviceId: 'device-current',
        state: state,
        recentFiles: [VaultPath('Note.md')],
      );

      final map = await store.readMap(fs, workspacePath);
      expect(map.containsKey('device-other'), isTrue);
      expect(map['device-other'], equals({'axis': 'vertical', 'focused': 1}));
      expect(map.containsKey('device-current'), isTrue);

      final current = map['device-current']! as Map<String, Object?>;
      expect(current['axis'], equals('horizontal'));
      expect(current['recent'], equals(['Note.md']));
    },
  );

  test('restore drops missing files and keeps order/mode/index', () async {
    // Note1 exists, Note2 does not exist
    await fs.writeText(VaultPath('Note1.md'), const TextDocument(text: ''));

    const store = TephraJsonStore();
    final workspacePath = VaultPath('.tephra/workspace.json');
    await store.writeMap(fs, workspacePath, {
      'my-device': {
        'panes': [
          {
            'tabs': [
              {
                'history': [
                  {'kind': 'file', 'path': 'Missing1.md'},
                  {'kind': 'file', 'path': 'Note1.md'},
                  {'kind': 'file', 'path': 'Missing2.md'},
                ],
                'index': 1,
                'mode': 'source',
              },
            ],
            'active': 0,
          },
        ],
        'axis': 'vertical',
        'recent': ['Note1.md', 'Missing1.md'],
      },
    });

    final restored = await persistence.restore(fs: fs, deviceId: 'my-device');
    expect(restored, isNotNull);
    final state = restored!.state;
    expect(state.panes.length, equals(1));
    expect(state.panes[0].tabs.length, equals(1));
    final tab = state.panes[0].tabs[0];
    expect(tab.history.length, equals(1));
    expect(tab.history[0], equals(FileTabContent(VaultPath('Note1.md'))));
    expect(tab.historyIndex, equals(0));
    expect(tab.mode, equals(ViewMode.source));
  });

  test('invalid JSON file -> empty workspace, no throw', () async {
    await fs.writeBytes(
      VaultPath('.tephra/workspace.json'),
      utf8.encode('{ invalid json'),
    );

    final restored = await persistence.restore(fs: fs, deviceId: 'my-device');
    expect(restored, isNull);
  });

  test('debounce: three rapid changes produce one write (fs.writeCount delta 1 after pumping 600 ms)', () async {
    final container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(deviceId: 'debounce-device'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vaultSessionProvider.notifier)
        .set(
          VaultSession(
            vaultId: 'session',
            rootDir: '/mem',
            name: 'Mem',
            fs: fs,
            settings: const VaultSettings(),
          ),
        );

    final initialWriteCount = fs.writeCount;
    final notifier = container.read(workspaceProvider.notifier);

    notifier.openPath(VaultPath('A.md'));
    notifier.openPath(VaultPath('B.md'), newTab: true);
    notifier.openPath(VaultPath('C.md'), newTab: true);

    // Immediately after rapid changes, saveTimer has not fired
    expect(fs.writeCount, equals(initialWriteCount));

    // After 600 ms, saveTimer fires once
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(fs.writeCount, equals(initialWriteCount + 1));
  });
}
