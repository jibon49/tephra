// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_palette.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/providers.dart';
import 'package:tephra/commands/tephra_command.dart';
import 'package:tephra/settings/app_settings.dart';

import '../helpers/test_app.dart';

void main() {
  group('CommandPalette', () {
    late CommandRegistry registry;
    var ranCommandId = '';

    setUp(() {
      ranCommandId = '';
      registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'test.bold',
          label: (_) => 'Toggle bold',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ],
          run: (_, _) {
            ranCommandId = 'test.bold';
          },
        ),
      );
      registry.register(
        TephraCommand(
          id: 'test.italic',
          label: (_) => 'Toggle italic',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyI, control: true),
          ],
          run: (_, _) {
            ranCommandId = 'test.italic';
          },
        ),
      );
      registry.register(
        TephraCommand(
          id: 'test.hidden',
          label: (_) => 'Hidden command',
          showInPalette: false,
          run: (_, _) {},
        ),
      );
      registry.register(
        TephraCommand(
          id: 'test.unavailable',
          label: (_) => 'Unavailable command',
          isAvailable: (_) => false,
          run: (_, _) {},
        ),
      );
    });

    testWidgets('shows dialog on desktop (1200 dp) and lists commands', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
          size: const Size(1200, 800),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('palette.query')), findsOneWidget);
      expect(find.text('Toggle bold'), findsOneWidget);
      expect(find.text('Toggle italic'), findsOneWidget);
      expect(find.text('Hidden command'), findsNothing);
      expect(find.text('Unavailable command'), findsNothing);
      expect(find.text('Ctrl+B'), findsOneWidget);
      expect(find.text('Ctrl+I'), findsOneWidget);
    });

    testWidgets('shows fullscreen dialog on phone (400 dp)', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
          size: const Size(400, 800),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Toggle bold'), findsOneWidget);
    });

    testWidgets('typing "bol" ranks Toggle bold first', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('palette.query')), 'bol');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette.row.test.bold')), findsOneWidget);
      expect(find.byKey(const Key('palette.row.test.italic')), findsNothing);
    });

    testWidgets('Enter runs highlighted command and closes', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette.query')), findsNothing);
      expect(ranCommandId, 'test.bold');
    });

    testWidgets('Escape closes dialog', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette.query')), findsNothing);
      expect(ranCommandId, isEmpty);
    });

    testWidgets('empty query shows recent commands first', (tester) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandPalette(context),
              child: const Text('Open'),
            ),
          ),
          appSettings: const AppSettings(
            deviceId: 'test-dev',
            recentCommands: ['test.italic'],
          ),
          overrides: [commandRegistryProvider.overrideWithValue(registry)],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Press Enter immediately -> should run test.italic first!
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(ranCommandId, 'test.italic');
    });
  });
}
