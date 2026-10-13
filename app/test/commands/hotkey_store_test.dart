// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/hotkey_store.dart';
import 'package:tephra/commands/tephra_command.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('HotkeyStore', () {
    test('load skips invalid strings', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('.tephra/hotkeys.json'),
        TextDocument(
          text: jsonEncode({
            'cmd1': ['Ctrl+K', 'InvalidCombo+', 'Ctrl+P'],
          }),
        ),
      );

      final store = HotkeyStore(fs);
      final loaded = await store.load();

      expect(loaded['cmd1'], hasLength(2));
      expect(loaded['cmd1']![0].trigger, LogicalKeyboardKey.keyK);
      expect(loaded['cmd1']![1].trigger, LogicalKeyboardKey.keyP);
    });

    test(
      'save writes only differing ids and removes default-equal ids',
      () async {
        final fs = MemoryVaultFileSystem();
        final registry = CommandRegistry();
        registry.register(
          TephraCommand(
            id: 'cmd1',
            label: (_) => 'One',
            defaultShortcuts: const [
              SingleActivator(LogicalKeyboardKey.keyA, control: true),
            ],
            run: (_, _) {},
          ),
        );
        registry.register(
          TephraCommand(
            id: 'cmd2',
            label: (_) => 'Two',
            defaultShortcuts: const [
              SingleActivator(LogicalKeyboardKey.keyB, control: true),
            ],
            run: (_, _) {},
          ),
        );

        final store = HotkeyStore(fs, registry: registry);

        // Save an override for cmd1, and default for cmd2
        await store.save({
          'cmd1': const [
            SingleActivator(LogicalKeyboardKey.keyZ, control: true),
          ],
          'cmd2': const [
            SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ],
        });

        final text = await fs.readText(VaultPath('.tephra/hotkeys.json'));
        final json = jsonDecode(text.text) as Map<String, dynamic>;

        expect(json.containsKey('cmd1'), isTrue);
        expect(json['cmd1'], ['Ctrl+Z']);
        expect(json.containsKey('cmd2'), isFalse);
      },
    );

    test('unknown ids are preserved in the file', () async {
      final fs = MemoryVaultFileSystem();
      await fs.writeText(
        VaultPath('.tephra/hotkeys.json'),
        TextDocument(
          text: jsonEncode({
            'plugin.command': ['Ctrl+Shift+X'],
          }),
        ),
      );

      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'app.cmd',
          label: (_) => 'App',
          defaultShortcuts: const [],
          run: (_, _) {},
        ),
      );

      final store = HotkeyStore(fs, registry: registry);
      await store.save({
        'app.cmd': const [
          SingleActivator(LogicalKeyboardKey.keyM, control: true),
        ],
      });

      final text = await fs.readText(VaultPath('.tephra/hotkeys.json'));
      final json = jsonDecode(text.text) as Map<String, dynamic>;

      expect(json['plugin.command'], ['Ctrl+Shift+X']);
      expect(json['app.cmd'], ['Ctrl+M']);
    });

    test('[] round-trips for unbinding', () async {
      final fs = MemoryVaultFileSystem();
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'cmd1',
          label: (_) => 'One',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyA, control: true),
          ],
          run: (_, _) {},
        ),
      );

      final store = HotkeyStore(fs, registry: registry);
      await store.save({'cmd1': const []});

      final loaded = await store.load();
      expect(loaded.containsKey('cmd1'), isTrue);
      expect(loaded['cmd1'], isEmpty);
    });
  });
}
