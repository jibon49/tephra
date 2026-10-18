// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../model/index_options.dart';

/// Returns true if [path] should be included in the index.
///
/// Returns false when:
/// - Any path segment starts with `.` (hidden files, `.obsidian`, `.tephra`, `.trash`, `.git`)
/// - Any segment equals `node_modules`
/// - The path is equal to or within any entry in [options.excludedFolders] (case-insensitively)
bool isIndexable(VaultPath path, IndexOptions options) {
  if (path.isRoot) return false;

  final segments = path.value.split('/');
  for (final seg in segments) {
    if (seg.startsWith('.') || seg == 'node_modules') {
      return false;
    }
  }

  final pathCase = path.caseKey;
  for (final ex in options.excludedFolders) {
    var exCase = ex.trim().replaceAll(r'\', '/').toLowerCase();
    while (exCase.startsWith('/')) {
      exCase = exCase.substring(1);
    }
    while (exCase.endsWith('/')) {
      exCase = exCase.substring(0, exCase.length - 1);
    }
    if (exCase.isEmpty) continue;
    if (pathCase == exCase || pathCase.startsWith('$exCase/')) {
      return false;
    }
  }

  return true;
}
