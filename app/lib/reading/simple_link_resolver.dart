// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Phase 1 simple link resolver implementing conventions for note and file lookup.
final class SimpleLinkResolver {
  const SimpleLinkResolver();

  /// Resolves [target] link string relative to [from] note among [files].
  VaultPath? resolve(
    String target, {
    required VaultPath from,
    required List<VaultPath> files,
  }) {
    final t = target.trim().replaceAll(r'\', '/');
    if (t.isEmpty) return from;

    final List<VaultPath> candidates;

    if (t.contains('/')) {
      final lowerT = t.toLowerCase();
      final lowerTMd = lowerT.endsWith('.md') ? lowerT : '$lowerT.md';

      final exact = files
          .where((f) => f.caseKey == lowerT || f.caseKey == lowerTMd)
          .toList();
      if (exact.isNotEmpty) {
        candidates = exact;
      } else {
        final suffix1 = '/$lowerT';
        final suffix2 = '/$lowerTMd';
        candidates = files
            .where(
              (f) => f.caseKey.endsWith(suffix1) || f.caseKey.endsWith(suffix2),
            )
            .toList();
      }
    } else {
      final dot = t.lastIndexOf('.');
      final hasExtension = dot > 0;

      if (hasExtension) {
        candidates = files
            .where((f) => f.name.toLowerCase() == t.toLowerCase())
            .toList();
      } else {
        final lower = t.toLowerCase();
        final mdMatches = files
            .where((f) => f.isMarkdown && f.stem.toLowerCase() == lower)
            .toList();
        if (mdMatches.isNotEmpty) {
          candidates = mdMatches;
        } else {
          candidates = files
              .where((f) => f.stem.toLowerCase() == lower)
              .toList();
        }
      }
    }

    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    candidates.sort(_compareCandidates);
    return candidates.first;
  }

  static int _compareCandidates(VaultPath a, VaultPath b) {
    // 1. Fewest path segments
    final segCountA = a.value.isEmpty ? 0 : a.value.split('/').length;
    final segCountB = b.value.isEmpty ? 0 : b.value.split('/').length;
    final segDiff = segCountA.compareTo(segCountB);
    if (segDiff != 0) return segDiff;

    // 2. Shorter value string length
    final lenDiff = a.value.length.compareTo(b.value.length);
    if (lenDiff != 0) return lenDiff;

    // 3. compareTo tie-break
    return a.compareTo(b);
  }
}
