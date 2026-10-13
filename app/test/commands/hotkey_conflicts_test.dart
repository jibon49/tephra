// © 2026 Tephra. All rights reserved.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/commands/hotkey_conflicts.dart';
import 'package:tephra/commands/tephra_command.dart';

void main() {
  group('HotkeyConflicts', () {
    test(
      'two commands sharing Ctrl+B produce one conflict entry listing both',
      () {
        final registry = CommandRegistry();
        registry.register(
          TephraCommand(
            id: 'bold',
            label: (_) => 'Bold',
            defaultShortcuts: const [
              SingleActivator(LogicalKeyboardKey.keyB, control: true),
            ],
            run: (_, _) {},
          ),
        );
        registry.register(
          TephraCommand(
            id: 'bookmarks',
            label: (_) => 'Bookmarks',
            defaultShortcuts: const [
              SingleActivator(LogicalKeyboardKey.keyB, control: true),
            ],
            run: (_, _) {},
          ),
        );

        final conflicts = findHotkeyConflicts(registry, const {});
        expect(conflicts.containsKey('Ctrl+B'), isTrue);
        expect(conflicts['Ctrl+B'], ['bold', 'bookmarks']);

        final forBold = conflictsFor('Ctrl+B', 'bold', registry, const {});
        expect(forBold, ['bookmarks']);
      },
    );

    test('an override resolving it results in no conflict', () {
      final registry = CommandRegistry();
      registry.register(
        TephraCommand(
          id: 'bold',
          label: (_) => 'Bold',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ],
          run: (_, _) {},
        ),
      );
      registry.register(
        TephraCommand(
          id: 'bookmarks',
          label: (_) => 'Bookmarks',
          defaultShortcuts: const [
            SingleActivator(LogicalKeyboardKey.keyB, control: true),
          ],
          run: (_, _) {},
        ),
      );

      final overrides = {
        'bookmarks': const [
          SingleActivator(LogicalKeyboardKey.keyD, control: true),
        ],
      };

      final conflicts = findHotkeyConflicts(registry, overrides);
      expect(conflicts, isEmpty);
      expect(conflictsFor('Ctrl+B', 'bold', registry, overrides), isEmpty);
    });
  });
}
