// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/tephra_command.dart';

void main() {
  group('CommandRegistry', () {
    test('duplicate id throws StateError', () {
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(id: 'test.cmd', label: (_) => 'Test', run: (_, _) {}),
      );

      expect(
        () => registry.register(
          TephraCommand(
            id: 'test.cmd',
            label: (_) => 'Duplicate',
            run: (_, _) {},
          ),
        ),
        throwsStateError,
      );
    });

    test('all keeps registration order', () {
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(id: 'c', label: (_) => 'C', run: (_, _) {}),
      );
      registry.register(
        TephraCommand(id: 'a', label: (_) => 'A', run: (_, _) {}),
      );
      registry.register(
        TephraCommand(id: 'b', label: (_) => 'B', run: (_, _) {}),
      );

      expect(registry.all.map((c) => c.id).toList(), ['c', 'a', 'b']);
    });

    test('shortcutsMap with defaults', () {
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'test.one',
          label: (_) => 'One',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyA, control: true),
          ],
          run: (_, _) {},
        ),
      );

      final map = registry.shortcutsMap(const {});
      expect(map['Ctrl+A'], 'test.one');
    });

    test('override replaces defaults of that command only', () {
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

      final overrides = {
        'cmd1': const [SingleActivator(LogicalKeyboardKey.keyC, control: true)],
      };

      final map = registry.shortcutsMap(overrides);
      expect(map['Ctrl+A'], isNull);
      expect(map['Ctrl+C'], 'cmd1');
      expect(map['Ctrl+B'], 'cmd2');
    });

    test('override of [] unbinds command', () {
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

      final overrides = {'cmd1': const <SingleActivator>[]};
      final map = registry.shortcutsMap(overrides);
      expect(map['Ctrl+A'], isNull);
      expect(registry.effectiveShortcuts('cmd1', overrides), isEmpty);
    });

    test('first-registered wins a shortcut conflict', () {
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'first',
          label: (_) => 'First',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyA, control: true),
          ],
          run: (_, _) {},
        ),
      );
      registry.register(
        TephraCommand(
          id: 'second',
          label: (_) => 'Second',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyA, control: true),
          ],
          run: (_, _) {},
        ),
      );

      final map = registry.shortcutsMap(const {});
      expect(map['Ctrl+A'], 'first');
    });

    test('effectiveShortcuts for an unknown id returns empty list', () {
      final registry = CommandRegistry();
      expect(registry.effectiveShortcuts('nonexistent', const {}), isEmpty);
    });
  });
}
