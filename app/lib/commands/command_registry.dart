// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';

import 'shortcut_codec.dart';
import 'tephra_command.dart';

final class CommandRegistry {
  final Map<String, TephraCommand> _commands = {};
  final List<TephraCommand> _order = [];

  void register(TephraCommand command) {
    if (_commands.containsKey(command.id)) {
      throw StateError('Duplicate command id: ${command.id}');
    }
    _commands[command.id] = command;
    _order.add(command);
  }

  TephraCommand? byId(String id) => _commands[id];

  List<TephraCommand> get all => List.unmodifiable(_order);

  List<SingleActivator> effectiveShortcuts(
    String id,
    Map<String, List<SingleActivator>> overrides,
  ) {
    final cmd = _commands[id];
    if (cmd == null) return const [];
    if (overrides.containsKey(id)) {
      return overrides[id]!;
    }
    return cmd.defaultShortcuts;
  }

  Map<String, String> shortcutsMap(
    Map<String, List<SingleActivator>> overrides,
  ) {
    final map = <String, String>{};
    for (final cmd in _order) {
      final shortcuts = effectiveShortcuts(cmd.id, overrides);
      for (final a in shortcuts) {
        final canonical = formatShortcut(a);
        if (!map.containsKey(canonical)) {
          map[canonical] = cmd.id;
        }
      }
    }
    return map;
  }
}
