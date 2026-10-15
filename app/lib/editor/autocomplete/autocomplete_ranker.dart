// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

import '../../commands/quick_switcher_items.dart';
import 'autocomplete_item.dart';
import 'block_candidates.dart';

final _logger = Logger('autocomplete');

/// Pure ranking functions for editor autocomplete.
abstract final class AutocompleteRanker {
  /// Ranks notes and aliases (and attachments when [includeAttachments] is true)
  /// using [FuzzyScorer].
  static List<AcItem> rankNotes(
    String query,
    List<SwitcherItem> items,
    List<VaultPath> recent, {
    bool includeAttachments = false,
    List<FileRecord> attachments = const [],
    int max = 50,
    List<AcItem>? previousCandidates,
  }) {
    final sw = Stopwatch()..start();
    final q = query.trim();

    if (q.isEmpty) {
      final result = <AcItem>[];
      final seenPaths = <VaultPath>{};

      // 1. Recents first
      for (final r in recent) {
        if (result.length >= max) break;
        if (!seenPaths.add(r)) continue;

        // Try to find in items
        SwitcherItem? matched;
        for (final item in items) {
          if (item.path == r && !item.isAlias) {
            matched = item;
            break;
          }
        }

        if (matched != null) {
          if (matched.isAttachment && !includeAttachments) continue;
          result.add(
            AcItem(
              kind: matched.isAttachment ? AcKind.attachment : AcKind.note,
              primary: matched.primary,
              secondary: matched.secondary.isEmpty ? null : matched.secondary,
              score: 0,
              matchRanges: const [],
              payload: matched.path,
            ),
          );
        } else if (r.isMarkdown) {
          result.add(
            AcItem(
              kind: AcKind.note,
              primary: r.stem,
              secondary: r.parent?.value,
              score: 0,
              matchRanges: const [],
              payload: r,
            ),
          );
        }
      }

      // 2. Remaining items if < max
      if (result.length < max) {
        for (final item in items) {
          if (result.length >= max) break;
          if (item.isAlias) continue;
          if (item.isAttachment && !includeAttachments) continue;
          if (!seenPaths.add(item.path)) continue;

          result.add(
            AcItem(
              kind: item.isAttachment ? AcKind.attachment : AcKind.note,
              primary: item.primary,
              secondary: item.secondary.isEmpty ? null : item.secondary,
              score: 0,
              matchRanges: const [],
              payload: item.path,
            ),
          );
        }
      }

      sw.stop();
      _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
      return result;
    }

    // Narrowing: if previousCandidates was supplied, score only those candidates
    if (previousCandidates != null) {
      final top = <(AcItem, int, VaultPath)>[];
      for (final cand in previousCandidates) {
        final VaultPath path;
        final bool isNote = cand.kind == AcKind.note;
        if (cand.payload is VaultPath) {
          path = cand.payload as VaultPath;
        } else if (cand.payload is (VaultPath, String)) {
          path = (cand.payload as (VaultPath, String)).$1;
        } else {
          continue;
        }

        final primaryScore = FuzzyScorer.score(q, cand.primary);
        int? pathScore;
        if (q.contains('/')) {
          final rawPath = FuzzyScorer.score(q, path.value);
          if (rawPath != null) pathScore = rawPath - 100;
        }

        int? matchScore;
        if (primaryScore != null && pathScore != null) {
          matchScore = math.max(primaryScore, pathScore);
        } else if (primaryScore != null) {
          matchScore = primaryScore;
        } else if (pathScore != null) {
          matchScore = pathScore;
        }

        if (matchScore == null) continue;

        final int recentBoost;
        if (!isNote || recent.isEmpty) {
          recentBoost = 0;
        } else {
          final recentRank = recent.indexOf(path);
          recentBoost = (recentRank >= 0 && recentRank < 10)
              ? math.max(0, 50 - 5 * recentRank)
              : 0;
        }
        final totalScore = matchScore + recentBoost;

        if (top.length == max && totalScore < top.last.$2) continue;

        _insertTopK(top, (cand, totalScore, path), max, (a, b) {
          final cmp = b.$2.compareTo(a.$2);
          if (cmp != 0) return cmp;
          final lenCmp = a.$3.value.length.compareTo(b.$3.value.length);
          if (lenCmp != 0) return lenCmp;
          final pathCmp = a.$3.value.compareTo(b.$3.value);
          if (pathCmp != 0) return pathCmp;
          return a.$1.primary.compareTo(b.$1.primary);
        });
      }

      final result = top.map((e) {
        final cand = e.$1;
        return AcItem(
          kind: cand.kind,
          primary: cand.primary,
          secondary: cand.secondary,
          score: e.$2,
          matchRanges: FuzzyScorer.matchRanges(q, cand.primary),
          payload: cand.payload,
        );
      }).toList();
      sw.stop();
      _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
      return result;
    }

    final top = <(SwitcherItem, int)>[];

    int compareSwitcher((SwitcherItem, int) a, (SwitcherItem, int) b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      final lenCmp = a.$1.path.value.length.compareTo(b.$1.path.value.length);
      if (lenCmp != 0) return lenCmp;
      final pathCmp = a.$1.path.value.compareTo(b.$1.path.value);
      if (pathCmp != 0) return pathCmp;
      return a.$1.primary.compareTo(b.$1.primary);
    }

    final qLower = q.toLowerCase();
    final qHasSlash = q.contains('/');

    // Score items
    for (final item in items) {
      if (item.isAttachment && !includeAttachments) continue;

      final primaryScore = FuzzyScorer.scoreLower(qLower, item.primaryLower);
      int? pathScore;
      if (qHasSlash) {
        final rawPath = FuzzyScorer.scoreLower(qLower, item.pathLower);
        if (rawPath != null) pathScore = rawPath - 100;
      }

      int? matchScore;
      if (primaryScore != null && pathScore != null) {
        matchScore = math.max(primaryScore, pathScore);
      } else if (primaryScore != null) {
        matchScore = primaryScore;
      } else if (pathScore != null) {
        matchScore = pathScore;
      }

      if (matchScore == null) continue;

      final isNote = !item.isAlias && !item.isAttachment;
      final int recentBoost;
      if (!isNote || recent.isEmpty) {
        recentBoost = 0;
      } else {
        final recentRank = recent.indexOf(item.path);
        recentBoost = (recentRank >= 0 && recentRank < 10)
            ? math.max(0, 50 - 5 * recentRank)
            : 0;
      }
      final totalScore = matchScore + recentBoost;

      if (top.length == max && totalScore < top.last.$2) continue;

      _insertTopK(top, (item, totalScore), max, compareSwitcher);
    }

    // Attachments passed separately
    if (includeAttachments && attachments.isNotEmpty) {
      for (final att in attachments) {
        final p = att.path;
        final primary = p.name;
        final primaryLower = primary.toLowerCase();
        final primaryScore = FuzzyScorer.scoreLower(qLower, primaryLower);
        int? pathScore;
        if (qHasSlash) {
          final rawPath = FuzzyScorer.scoreLower(qLower, p.value.toLowerCase());
          if (rawPath != null) pathScore = rawPath - 100;
        }

        int? matchScore;
        if (primaryScore != null && pathScore != null) {
          matchScore = math.max(primaryScore, pathScore);
        } else if (primaryScore != null) {
          matchScore = primaryScore;
        } else if (pathScore != null) {
          matchScore = pathScore;
        }

        if (matchScore == null) continue;

        final folder = p.parent?.value;
        final item = SwitcherItem(
          path: p,
          primary: primary,
          secondary: folder ?? '',
          isAttachment: true,
        );
        _insertTopK(top, (item, matchScore), max, compareSwitcher);
      }
    }

    final result = top.map((e) {
      final item = e.$1;
      final AcKind kind;
      final Object payload;
      if (item.isAlias) {
        kind = AcKind.alias;
        payload = (item.path, item.primary);
      } else if (item.isAttachment) {
        kind = AcKind.attachment;
        payload = item.path;
      } else {
        kind = AcKind.note;
        payload = item.path;
      }

      return AcItem(
        kind: kind,
        primary: item.primary,
        secondary: item.secondary.isEmpty ? null : item.secondary,
        score: e.$2,
        matchRanges: FuzzyScorer.matchRanges(q, item.primary),
        payload: payload,
      );
    }).toList();
    sw.stop();
    _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
    return result;
  }

  static void _insertTopK<T>(
    List<T> top,
    T candidate,
    int max,
    int Function(T, T) compare,
  ) {
    if (top.length == max) {
      if (compare(candidate, top.last) >= 0) return;
    }

    var low = 0;
    var high = top.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (compare(candidate, top[mid]) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    top.insert(low, candidate);
    if (top.length > max) {
      top.removeLast();
    }
  }

  /// Ranks headings by [FuzzyScorer.score] or keeps document order when [query] is empty.
  static List<AcItem> rankHeadings(
    String query,
    List<HeadingRecord> headings, {
    int max = 50,
  }) {
    final sw = Stopwatch()..start();
    final q = query.trim();

    if (q.isEmpty) {
      final result = headings
          .take(max)
          .map(
            (h) => AcItem(
              kind: AcKind.heading,
              primary: h.text,
              secondary: 'H${h.level}',
              score: 0,
              matchRanges: const [],
              payload: h,
            ),
          )
          .toList();
      sw.stop();
      _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
      return result;
    }

    final scored = <(AcItem, int, int)>[];
    for (var i = 0; i < headings.length; i++) {
      final h = headings[i];
      final s = FuzzyScorer.score(q, h.text);
      if (s != null) {
        scored.add((
          AcItem(
            kind: AcKind.heading,
            primary: h.text,
            secondary: 'H${h.level}',
            score: s,
            matchRanges: FuzzyScorer.matchRanges(q, h.text),
            payload: h,
          ),
          s,
          i,
        ));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$3.compareTo(b.$3);
    });

    final top = scored.take(max).map((e) => e.$1).toList();
    sw.stop();
    _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
    return top;
  }

  /// Ranks blocks by [preview] and [existingId].
  static List<AcItem> rankBlocks(
    String query,
    List<BlockCandidate> blocks, {
    int max = 50,
  }) {
    final sw = Stopwatch()..start();
    final q = query.trim();

    if (q.isEmpty) {
      final result = blocks
          .take(max)
          .map(
            (b) => AcItem(
              kind: AcKind.block,
              primary: b.preview,
              secondary: b.existingId == null ? null : '^${b.existingId}',
              score: 0,
              matchRanges: const [],
              payload: b,
            ),
          )
          .toList();
      sw.stop();
      _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
      return result;
    }

    final hasSpace = q.contains(' ');
    final scored = <(AcItem, int, int)>[];

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final previewScore = FuzzyScorer.score(q, b.preview);
      int? idScore;
      if (!hasSpace && b.existingId != null) {
        idScore = FuzzyScorer.score(q, b.existingId!);
      }

      int? s;
      if (previewScore != null && idScore != null) {
        s = math.max(previewScore, idScore);
      } else if (previewScore != null) {
        s = previewScore;
      } else if (idScore != null) {
        s = idScore;
      }

      if (s != null) {
        final matchRanges = FuzzyScorer.matchRanges(q, b.preview);
        scored.add((
          AcItem(
            kind: AcKind.block,
            primary: b.preview,
            secondary: b.existingId == null ? null : '^${b.existingId}',
            score: s,
            matchRanges: matchRanges,
            payload: b,
          ),
          s,
          i,
        ));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$3.compareTo(b.$3);
    });

    final top = scored.take(max).map((e) => e.$1).toList();
    sw.stop();
    _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
    return top;
  }

  /// Ranks aliases by [FuzzyScorer.score].
  static List<AcItem> rankAliases(
    String query,
    List<String> aliases, {
    int max = 50,
  }) {
    final sw = Stopwatch()..start();
    final q = query.trim();

    if (q.isEmpty) {
      final result = aliases
          .take(max)
          .map(
            (a) => AcItem(
              kind: AcKind.alias,
              primary: a,
              score: 0,
              matchRanges: const [],
              payload: a,
            ),
          )
          .toList();
      sw.stop();
      _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
      return result;
    }

    final scored = <(AcItem, int, int)>[];
    for (var i = 0; i < aliases.length; i++) {
      final a = aliases[i];
      final s = FuzzyScorer.score(q, a);
      if (s != null) {
        scored.add((
          AcItem(
            kind: AcKind.alias,
            primary: a,
            score: s,
            matchRanges: FuzzyScorer.matchRanges(q, a),
            payload: a,
          ),
          s,
          i,
        ));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$3.compareTo(b.$3);
    });

    final top = scored.take(max).map((e) => e.$1).toList();
    sw.stop();
    _logger.fine('perf autocomplete ${sw.elapsedMilliseconds} ms');
    return top;
  }
}
