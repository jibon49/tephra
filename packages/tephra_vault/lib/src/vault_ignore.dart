// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

final class VaultIgnore {
  const VaultIgnore({this.showHidden = false, this.excludedFolders = const []});

  static const Set<String> alwaysIgnoredSegments = {
    '.obsidian',
    '.tephra',
    '.trash',
    '.git',
    'node_modules',
  };

  final bool showHidden;
  final List<VaultPath> excludedFolders;

  /// True when [path] must not appear in listings, watcher events or (later) the index.
  bool isIgnored(VaultPath path) {
    if (path.isRoot) return false;

    final segments = path.value.split('/');
    for (final seg in segments) {
      if (alwaysIgnoredSegments.contains(seg.toLowerCase())) {
        return true;
      }
      if (!showHidden && seg.startsWith('.')) {
        return true;
      }
    }

    for (final excluded in excludedFolders) {
      if (path.caseKey == excluded.caseKey ||
          path.caseKey.startsWith('${excluded.caseKey}/')) {
        return true;
      }
    }

    return false;
  }
}
