// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';

import 'command_registry.dart';
import 'shortcut_codec.dart';

Map<String, List<String>> findHotkeyConflicts(
  CommandRegistry registry,
  Map<String, List<SingleActivator>> overrides,
) {
  final map = <String, List<String>>{};

  for (final cmd in registry.all) {
    final shortcuts = registry.effectiveShortcuts(cmd.id, overrides);
    for (final a in shortcuts) {
      final canonical = formatShortcut(a);
      map.putIfAbsent(canonical, () => []).add(cmd.id);
    }
  }

  final conflicts = <String, List<String>>{};
  for (final entry in map.entries) {
    if (entry.value.length >= 2) {
      conflicts[entry.key] = entry.value;
    }
  }

  return conflicts;
}

List<String> conflictsFor(
  String shortcut,
  String exceptCommandId,
  CommandRegistry registry,
  Map<String, List<SingleActivator>> overrides,
) {
  final result = <String>[];
  for (final cmd in registry.all) {
    if (cmd.id == exceptCommandId) continue;
    final shortcuts = registry.effectiveShortcuts(cmd.id, overrides);
    if (shortcuts.any((s) => formatShortcut(s) == shortcut)) {
      result.add(cmd.id);
    }
  }
  return result;
}
