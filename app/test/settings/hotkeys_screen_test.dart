// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/tephra_command.dart';
import 'package:tephra/settings/hotkeys_screen.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  group('HotkeysScreen', () {
    late MemoryVaultFileSystem fs;
    late CommandRegistry registry;

    setUp(() {
      fs = MemoryVaultFileSystem();
      registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'test.bold',
          label: (_) => 'Toggle bold',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ],
          run: (_, _) {},
        ),
      );
      registry.register(
        TephraCommand(
          id: 'test.italic',
          label: (_) => 'Toggle italic',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyI, control: true),
          ],
          run: (_, _) {},
        ),
      );
    });

    testWidgets(
      'rows listed and recording Ctrl+Shift+K adds a chip and writes hotkeys.json',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const HotkeysScreen(),
            fs: fs,
            overrides: [commandRegistryProvider.overrideWithValue(registry)],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Toggle bold'), findsOneWidget);
        expect(find.text('Toggle italic'), findsOneWidget);
        expect(find.text('Ctrl+B'), findsOneWidget);

        // Tap + on Toggle bold
        final addButtons = find.byIcon(Icons.add);
        await tester.tap(addButtons.first);
        await tester.pumpAndSettle();

        // Recorder dialog is open, send Ctrl+Shift+K
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.text('Ctrl+Shift+K'), findsOneWidget);

        final hotkeysFile = await fs.readText(
          VaultPath('.tephra/hotkeys.json'),
        );
        final map = jsonDecode(hotkeysFile.text) as Map<String, dynamic>;
        expect(map['test.bold'], contains('Ctrl+Shift+K'));
      },
    );

    testWidgets(
      'recording an in-use shortcut shows conflict dialog and Replace removes from other',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const HotkeysScreen(),
            fs: fs,
            overrides: [commandRegistryProvider.overrideWithValue(registry)],
          ),
        );

        await tester.pumpAndSettle();

        // Tap + on Toggle italic
        final addButtons = find.byIcon(Icons.add);
        await tester.tap(addButtons.last);
        await tester.pumpAndSettle();

        // Send Ctrl+B (already used by Toggle bold)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        // Conflict dialog should appear
        expect(find.text('Replace'), findsOneWidget);
        expect(find.text('Keep both'), findsOneWidget);

        // Tap Replace
        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();

        // Now Toggle italic has Ctrl+B, and Toggle bold no longer has Ctrl+B
        final boldRow = find.ancestor(
          of: find.text('Toggle bold'),
          matching: find.byType(ListTile),
        );
        final italicRow = find.ancestor(
          of: find.text('Toggle italic'),
          matching: find.byType(ListTile),
        );

        expect(
          find.descendant(of: boldRow, matching: find.text('Ctrl+B')),
          findsNothing,
        );
        expect(
          find.descendant(of: italicRow, matching: find.text('Ctrl+B')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Reset restores defaults', (tester) async {
      await tester.pumpWidget(
        testApp(
          const HotkeysScreen(),
          fs: fs,
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.pumpAndSettle();

      // Delete Ctrl+B chip from Toggle bold
      final deleteChip = find.descendant(
        of: find.byType(InputChip),
        matching: find.byIcon(Icons.cancel),
      );
      if (deleteChip.evaluate().isNotEmpty) {
        await tester.tap(deleteChip.first);
      } else {
        // Alternatively tap chip's delete icon
        final chip = tester.widget<InputChip>(find.byType(InputChip).first);
        chip.onDeleted?.call();
      }
      await tester.pumpAndSettle();

      // Tap Reset button
      expect(find.text('Reset'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+B'), findsOneWidget);
    });
  });
}
