// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/hotkey_host.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/tephra_command.dart';

import '../helpers/test_app.dart';

void main() {
  group('HotkeyHost', () {
    testWidgets('pressing Ctrl+P opens the palette', (tester) async {
      var ranCommand = false;
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'app.open-command-palette',
          label: (_) => 'Open command palette',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyP, control: true),
          ],
          run: (_, _) {
            ranCommand = true;
          },
        ),
      );

      await tester.pumpWidget(
        testApp(
          const HotkeyHost(
            child: Scaffold(body: Center(child: Text('Body'))),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(ranCommand, isTrue);
    });

    testWidgets(
      'unavailable command shortcut bubbles up (e.g. TextField receives key)',
      (tester) async {
        var ranCommand = false;
        final registry = CommandRegistry();
        registry.register(
          TephraCommand(
            id: 'test.unavailable',
            label: (_) => 'Unavailable',
            defaultShortcuts: const [
              SingleActivator(LogicalKeyboardKey.keyZ, control: true),
            ],
            isAvailable: (_) => false,
            run: (_, _) {
              ranCommand = true;
            },
          ),
        );

        final controller = TextEditingController(text: 'Hello');

        await tester.pumpWidget(
          testApp(
            HotkeyHost(
              child: Scaffold(
                body: TextField(controller: controller, autofocus: true),
              ),
            ),
            overrides: [commandRegistryProvider.overrideWithValue(registry)],
          ),
        );

        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(ranCommand, isFalse);
      },
    );

    testWidgets('override changes take effect without restart', (tester) async {
      var ranCommand = false;
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'test.custom',
          label: (_) => 'Custom',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyA, control: true),
          ],
          run: (_, _) {
            ranCommand = true;
          },
        ),
      );

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        testApp(
          Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const HotkeyHost(
                child: Scaffold(body: Center(child: Text('Content'))),
              );
            },
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.pumpAndSettle();

      // Change override to Ctrl+K
      await capturedRef
          .read(hotkeyOverridesProvider.notifier)
          .update(
            (m) => {
              ...m,
              'test.custom': const [
                SingleActivator(LogicalKeyboardKey.keyK, control: true),
              ],
            },
          );
      await tester.pumpAndSettle();

      // Press old shortcut Ctrl+A -> should NOT trigger
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(ranCommand, isFalse);

      // Press new shortcut Ctrl+K -> SHOULD trigger
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(ranCommand, isTrue);
    });
  });
}
