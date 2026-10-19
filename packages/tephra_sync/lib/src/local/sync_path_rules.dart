// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../model/selective_sync_rules.dart';

/// Evaluates whether paths participate in sync or should be ignored.
final class SyncPathRules {
  SyncPathRules._();

  /// Segments that are always ignored anywhere in the path hierarchy.
  static const Set<String> ignoredSegments = {
    '.obsidian',
    '.git',
    '.trash',
    'node_modules',
  };

  /// The only files within `.tephra/` that are synchronized across devices.
  static const Set<String> syncedTephraFiles = {
    '.tephra/settings.json',
    '.tephra/hotkeys.json',
    '.tephra/bookmarks.json',
    '.tephra/types.json',
    '.tephra/workspace.json',
    '.tephra/stickies.json',
  };

  /// Evaluates whether [path] with [size] in bytes participates in sync under [rules].
  ///
  /// Returns `false` if the path should be ignored on this device.
  static bool participates(VaultPath path, int size, SelectiveSyncRules rules) {
    if (path.isRoot) return false;
    if (size < 0) return false;

    final val = path.value;
    final name = path.name;

    final segments = val.split('/');

    // Temporary names used by executor
    if (name.endsWith('.tephra-tmp') || name.contains('.tephra-case-')) {
      return false;
    }
    for (final seg in segments) {
      if (seg.endsWith('.tephra-tmp') || seg.contains('.tephra-case-')) {
        return false;
      }
    }

    // Segments that are always ignored
    for (final seg in segments) {
      if (ignoredSegments.contains(seg)) {
        return false;
      }
    }

    // Tephra internal folder rules
    if (val == '.tephra' || val.startsWith('.tephra/')) {
      if (!syncedTephraFiles.contains(val)) {
        return false;
      }
    } else {
      // Hidden files or directories: any segment starting with '.'
      for (final seg in segments) {
        if (seg.startsWith('.')) {
          return false;
        }
      }
    }

    // Rules-based exclusions (folder prefix, extension, size limit)
    if (rules.isExcluded(val, size)) {
      return false;
    }

    return true;
  }
}
