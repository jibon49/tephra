// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

/// Shared ranking function for quick switcher, palette, and autocomplete.
abstract final class FuzzyScorer {
  static const _separators = <int>{
    0x20, // ' '
    0x2D, // '-'
    0x5F, // '_'
    0x2F, // '/'
    0x2E, // '.'
    0x28, // '('
    0x5B, // '['
  };

  static bool _isSeparator(int codeUnit) => _separators.contains(codeUnit);

  static bool _isWordStart(String s, int index) {
    if (index == 0) return true;
    return _isSeparator(s.codeUnitAt(index - 1));
  }

  /// Score of [candidate] for [query]; null = no match. Higher is better. Case-insensitive.
  static int? score(String query, String candidate) {
    return scoreLower(query.trim().toLowerCase(), candidate.toLowerCase());
  }

  /// Score of pre-lowercased [c] for pre-lowercased and trimmed [q].
  static int? scoreLower(String q, String c) {
    // 1. q empty -> 0
    if (q.isEmpty) return 0;

    // 2. c == q -> 1000
    if (c == q) return 1000;

    // 3. c.startsWith(q) -> 900 - min(100, c.length - q.length)
    if (c.startsWith(q)) {
      return 900 - math.min(100, c.length - q.length);
    }

    // 4 & 5. Find occurrences of q in c
    var firstWordStartIdx = -1;
    var firstOccurIdx = -1;
    var searchStart = 0;
    while (searchStart <= c.length - q.length) {
      final idx = c.indexOf(q, searchStart);
      if (idx == -1) break;
      if (firstOccurIdx == -1) {
        firstOccurIdx = idx;
      }
      if (_isWordStart(c, idx)) {
        firstWordStartIdx = idx;
        break;
      }
      searchStart = idx + 1;
    }

    // 4. Word start occurrence -> 700 - min(100, i)
    if (firstWordStartIdx != -1) {
      return 700 - math.min(100, firstWordStartIdx);
    }

    // 5. Substring occurrence -> 500 - min(100, i)
    if (firstOccurIdx != -1) {
      return 500 - math.min(100, firstOccurIdx);
    }

    // 6. Subsequence: match each character of q greedily in order in c
    final matchedIndices = <int>[];
    var cIdx = 0;
    for (var qIdx = 0; qIdx < q.length; qIdx++) {
      final qChar = q.codeUnitAt(qIdx);
      var found = false;
      while (cIdx < c.length) {
        if (c.codeUnitAt(cIdx) == qChar) {
          matchedIndices.add(cIdx);
          cIdx++;
          found = true;
          break;
        }
        cIdx++;
      }
      if (!found) return null;
    }

    // Gaps: number of consecutive matched-position pairs that are not adjacent
    var gaps = 0;
    for (var i = 0; i < matchedIndices.length - 1; i++) {
      if (matchedIndices[i + 1] - matchedIndices[i] > 1) {
        gaps++;
      }
    }

    // First matched index
    final firstIdx = matchedIndices.first;

    // Matched characters at word starts
    var wordStarts = 0;
    for (final idx in matchedIndices) {
      if (_isWordStart(c, idx)) {
        wordStarts++;
      }
    }

    final rawScore = 300 - 2 * gaps - math.min(50, firstIdx) + 10 * wordStarts;

    return rawScore.clamp(1, 399).toInt();
  }

  /// Character ranges of [candidate] matched by [query] (for bold rendering).
  static List<(int, int)> matchRanges(String query, String candidate) {
    final q = query.trim().toLowerCase();
    final c = candidate.toLowerCase();

    if (q.isEmpty || c.isEmpty) return const [];

    // Exact or prefix
    if (c == q || c.startsWith(q)) {
      return [(0, q.length)];
    }

    // Word start occurrence
    var searchStart = 0;
    while (searchStart <= c.length - q.length) {
      final idx = c.indexOf(q, searchStart);
      if (idx == -1) break;
      if (_isWordStart(c, idx)) {
        return [(idx, idx + q.length)];
      }
      searchStart = idx + 1;
    }

    // Substring occurrence
    final substrIdx = c.indexOf(q);
    if (substrIdx != -1) {
      return [(substrIdx, substrIdx + q.length)];
    }

    // Subsequence
    final matchedIndices = <int>[];
    var cIdx = 0;
    for (var qIdx = 0; qIdx < q.length; qIdx++) {
      final qChar = q.codeUnitAt(qIdx);
      var found = false;
      while (cIdx < c.length) {
        if (c.codeUnitAt(cIdx) == qChar) {
          matchedIndices.add(cIdx);
          cIdx++;
          found = true;
          break;
        }
        cIdx++;
      }
      if (!found) return const [];
    }

    // Merge adjacent ranges
    final ranges = <(int, int)>[];
    var rangeStart = matchedIndices.first;
    var rangeEnd = rangeStart + 1;

    for (var i = 1; i < matchedIndices.length; i++) {
      final idx = matchedIndices[i];
      if (idx == rangeEnd) {
        rangeEnd = idx + 1;
      } else {
        ranges.add((rangeStart, rangeEnd));
        rangeStart = idx;
        rangeEnd = idx + 1;
      }
    }
    ranges.add((rangeStart, rangeEnd));

    return ranges;
  }
}
