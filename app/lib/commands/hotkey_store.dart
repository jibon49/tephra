// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/json_file_store.dart';
import 'command_registry.dart';
import 'shortcut_codec.dart';

final class HotkeyStore {
  HotkeyStore(this.fs, {this.registry, TephraJsonStore? jsonStore})
    : _jsonStore = jsonStore ?? const TephraJsonStore();

  final VaultFileSystem fs;
  final CommandRegistry? registry;
  final TephraJsonStore _jsonStore;

  static final _hotkeysPath = VaultPath('.tephra/hotkeys.json');
  final _log = Logger('hotkeys');

  Future<Map<String, List<SingleActivator>>> load() async {
    final rawMap = await _jsonStore.readMap(fs, _hotkeysPath);
    final result = <String, List<SingleActivator>>{};

    for (final entry in rawMap.entries) {
      final id = entry.key;
      final val = entry.value;
      if (val is List) {
        final activators = <SingleActivator>[];
        for (final item in val) {
          if (item is String) {
            final parsed = parseShortcut(item);
            if (parsed != null) {
              activators.add(parsed);
            } else {
              _log.warning(
                'Skipping invalid shortcut "$item" for command "$id"',
              );
            }
          }
        }
        result[id] = activators;
      }
    }

    return result;
  }

  Future<void> save(Map<String, List<SingleActivator>> overrides) async {
    await _jsonStore.update(fs, _hotkeysPath, (map) {
      if (registry != null) {
        for (final cmd in registry!.all) {
          final override = overrides[cmd.id];
          if (override == null) {
            map.remove(cmd.id);
          } else {
            final defStrings = cmd.defaultShortcuts
                .map(formatShortcut)
                .toList();
            final currStrings = override.map(formatShortcut).toList();
            if (_listEquals(defStrings, currStrings)) {
              map.remove(cmd.id);
            } else {
              map[cmd.id] = currStrings;
            }
          }
        }
      }
      for (final entry in overrides.entries) {
        final id = entry.key;
        if (registry != null && registry!.byId(id) != null) {
          continue;
        }
        map[id] = entry.value.map(formatShortcut).toList();
      }
    });
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
