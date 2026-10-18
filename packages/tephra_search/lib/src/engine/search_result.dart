// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'search_match.dart';

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A matched note with its list of highlight matches.
final class SearchResult {
  const SearchResult(this.path, this.matches);

  /// Vault path of the matching note.
  final VaultPath path;

  /// Highlight occurrences within the note or its file name.
  final List<SearchMatch> matches;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchResult &&
          path == other.path &&
          _listEquals(matches, other.matches));

  @override
  int get hashCode => Object.hash(path, Object.hashAll(matches));

  @override
  String toString() => 'SearchResult(${path.value}, ${matches.length} matches)';
}
