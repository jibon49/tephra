// © 2026 Tephra. All rights reserved.

import 'dart:math';

abstract final class FuzzyMatcher {
  static const _separators = {' ', '-', '_', '/', '.', '(', '[', ':'};

  /// Calculates a match score for [candidate] against [query].
  ///
  /// Returns `null` if [candidate] does not contain [query] as a subsequence.
  /// Higher score is better. Case-insensitive.
  static int? score(String query, String candidate) {
    final q = query.trim().toLowerCase();
    final c = candidate.toLowerCase();

    if (q.isEmpty) return 0;
    if (q.length > c.length) return null;

    var totalScore = 0;
    var previousMatchIndex = -2;
    var firstMatchIndex = -1;
    var cIndex = 0;

    for (var qi = 0; qi < q.length; qi++) {
      final qChar = q[qi];
      var found = false;
      while (cIndex < c.length) {
        if (c[cIndex] == qChar) {
          found = true;
          if (firstMatchIndex == -1) {
            firstMatchIndex = cIndex;
          }

          totalScore += 10;
          if (cIndex == 0 || _separators.contains(c[cIndex - 1])) {
            totalScore += 15;
          }
          if (cIndex == previousMatchIndex + 1) {
            totalScore += 8;
          }

          previousMatchIndex = cIndex;
          cIndex++;
          break;
        }
        cIndex++;
      }

      if (!found) {
        return null;
      }
    }

    totalScore -= min(20, firstMatchIndex);
    totalScore -= (c.length - q.length) ~/ 4;

    if (c == q) {
      totalScore += 100;
    } else if (c.startsWith(q)) {
      totalScore += 50;
    }

    return totalScore;
  }

  /// Character ranges (start, end exclusive) of the greedy match in [candidate],
  /// with adjacent ranges merged for bold rendering.
  static List<(int, int)> matchRanges(String query, String candidate) {
    final q = query.trim().toLowerCase();
    final c = candidate.toLowerCase();

    if (q.isEmpty || q.length > c.length) return const [];

    final rawIndices = <int>[];
    var cIndex = 0;

    for (var qi = 0; qi < q.length; qi++) {
      final qChar = q[qi];
      var found = false;
      while (cIndex < c.length) {
        if (c[cIndex] == qChar) {
          found = true;
          rawIndices.add(cIndex);
          cIndex++;
          break;
        }
        cIndex++;
      }
      if (!found) return const [];
    }

    if (rawIndices.isEmpty) return const [];

    final merged = <(int, int)>[];
    var start = rawIndices[0];
    var end = start + 1;

    for (var i = 1; i < rawIndices.length; i++) {
      final idx = rawIndices[i];
      if (idx == end) {
        end++;
      } else {
        merged.add((start, end));
        start = idx;
        end = start + 1;
      }
    }
    merged.add((start, end));

    return merged;
  }
}
