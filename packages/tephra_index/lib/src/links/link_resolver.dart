// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'name_table.dart';
import 'resolved_target.dart';

/// Obsidian-compatible link resolver.
final class LinkResolver {
  const LinkResolver(this.lookup);

  /// Target lookup source (in-memory file and alias index).
  final LinkTargetLookup lookup;

  /// Resolves [target] against [lookup] from the context of [from].
  ///
  /// [target] is the link path only: no '#subpath', no '|alias', already
  /// URL-decoded for markdown links.
  ResolvedTarget? resolve(String target, {required VaultPath from}) {
    // 1. Normalize slashes and trim
    var t = target.trim().replaceAll(r'\', '/');
    if (t.isEmpty) {
      return ResolvedTarget(from, viaAlias: false);
    }

    // 2. Absolute / relative flags
    final absoluteOnly = t.startsWith('/');
    if (absoluteOnly) {
      while (t.startsWith('/')) {
        t = t.substring(1);
      }
      if (t.isEmpty) {
        return null;
      }
    }
    final relativeOnly = t.startsWith('./') || t.startsWith('../');

    // 3. Candidate spellings C
    final List<String> candidates;
    if (t.toLowerCase().endsWith('.md')) {
      candidates = [t];
    } else {
      candidates = ['$t.md', t];
    }

    // 4. Step A — exact vault path (skipped when relativeOnly)
    if (!relativeOnly) {
      for (final c in candidates) {
        final vp = _tryVaultPath(c);
        if (vp == null) continue;
        final hit = lookup.byCaseKey(vp.caseKey);
        if (hit != null) {
          return ResolvedTarget(hit, viaAlias: false);
        }
      }
    }

    // 5. If absoluteOnly, do not fall back further
    if (absoluteOnly) {
      return null;
    }

    // 6. Step B — relative to the source folder
    final base = from.parent;
    for (final c in candidates) {
      final combined = (base == null || base.isRoot || base.value.isEmpty)
          ? c
          : '${base.value}/$c';
      final vp = _tryVaultPath(combined);
      if (vp == null) continue;
      final hit = lookup.byCaseKey(vp.caseKey);
      if (hit != null) {
        return ResolvedTarget(hit, viaAlias: false);
      }
    }

    // 7. If relativeOnly, do not fall back to filename or aliases
    if (relativeOnly) {
      return null;
    }

    // 8. Step C — by file name anywhere
    for (final c in candidates) {
      final lastSlash = c.lastIndexOf('/');
      final seg = lastSlash == -1 ? c : c.substring(lastSlash + 1);
      final name = seg.toLowerCase();
      var matches = lookup.byNameKey(name);

      if (c.contains('/')) {
        final cLower = c.toLowerCase();
        final suffix = '/$cLower';
        matches = matches
            .where((m) => m.caseKey == cLower || m.caseKey.endsWith(suffix))
            .toList();
      }

      if (matches.isNotEmpty) {
        return ResolvedTarget(_pickShortest(matches), viaAlias: false);
      }
    }

    // 9. Step D — aliases (only when t contains no '/')
    if (!t.contains('/')) {
      final matches = lookup.byAliasKey(t.toLowerCase());
      if (matches.isNotEmpty) {
        return ResolvedTarget(_pickShortest(matches), viaAlias: true);
      }
    }

    // 10. Unresolved
    return null;
  }

  static VaultPath? _tryVaultPath(String raw) {
    try {
      return VaultPath(raw);
    } on InvalidPathException {
      return null;
    }
  }

  static VaultPath _pickShortest(List<VaultPath> list) {
    assert(list.isNotEmpty);
    if (list.length == 1) return list.first;

    final sorted = List<VaultPath>.of(list);
    sorted.sort((a, b) {
      final aSegments = a.value.split('/').length;
      final bSegments = b.value.split('/').length;
      final segCompare = aSegments.compareTo(bSegments);
      if (segCompare != 0) return segCompare;

      final caseCompare = a.caseKey.compareTo(b.caseKey);
      if (caseCompare != 0) return caseCompare;

      return a.value.compareTo(b.value);
    });
    return sorted.first;
  }
}
