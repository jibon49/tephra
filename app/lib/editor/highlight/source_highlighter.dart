// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../editor_engine.dart';
import '../line_view.dart';
import 'quick_styler.dart';
import 'source_styles.dart';
import 'span_extractor.dart';

/// An overlay styled range (e.g. for find & replace highlights).
final class OverlayRange {
  const OverlayRange({
    required this.start,
    required this.end,
    required this.token,
  });

  final int start;
  final int end;
  final SourceToken token;
}

final class _SpanCacheKey {
  const _SpanCacheKey(this.line, this.lineHash, this.revision, this.isDark);

  final int line;
  final int lineHash;
  final int revision;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpanCacheKey &&
          line == other.line &&
          lineHash == other.lineHash &&
          revision == other.revision &&
          isDark == other.isDark;

  @override
  int get hashCode => Object.hash(line, lineHash, revision, isDark);
}

/// Token highlighter for Source mode editor lines.
class SourceHighlighter {
  SourceHighlighter();

  final List<List<RangeStyle>> _lines = [];
  final Set<int> _dirtyLines = {};
  List<OverlayRange> _overlays = const [];

  int _currentRevision = 0;
  final Map<_SpanCacheKey, TextSpan> _spanCache = {};

  int get currentRevision => _currentRevision;
  int get lineCount => _lines.length;

  List<RangeStyle> runsForLine(int line) =>
      line >= 0 && line < _lines.length ? _lines[line] : const [];

  bool isLineDirty(int line) => _dirtyLines.contains(line);

  void setOverlays(List<OverlayRange> overlays) {
    _overlays = overlays;
    _spanCache.clear();
  }

  /// Ingests a new AST [parsed] snapshot at [revision] and updates cached line tokens.
  void applyParse(ParsedNote parsed, {required int revision}) {
    // Only accept newer or equal revisions
    if (revision < _currentRevision) return;
    _currentRevision = revision;

    final lineIndex = parsed.lines;
    final totalLines = lineIndex.lineCount;

    // Collect raw spans per line
    final lineRaw = List.generate(totalLines, (_) => <RawSpan>[]);
    final spans = extractSpans(parsed);

    for (final span in spans) {
      if (span.start >= span.end) continue;
      final startLine = lineIndex.lineOf(span.start);
      final startCol = span.start - lineIndex.lineStart(startLine);
      final endLine = lineIndex.lineOf(span.end);
      final endCol = span.end - lineIndex.lineStart(endLine);

      if (startLine == endLine) {
        if (startLine < totalLines) {
          lineRaw[startLine].add(RawSpan(startCol, endCol, span.token));
        }
      } else {
        // Multi-line span
        for (var l = startLine; l <= endLine && l < totalLines; l++) {
          final lStart = lineIndex.lineStart(l);
          final lEnd = lineIndex.lineEnd(l);
          final lLen = lEnd - lStart;

          final colStart = (l == startLine) ? startCol : 0;
          final colEnd = (l == endLine) ? endCol : lLen;
          if (colStart < colEnd) {
            lineRaw[l].add(RawSpan(colStart, colEnd, span.token));
          }
        }
      }
    }

    _lines.clear();
    for (var l = 0; l < totalLines; l++) {
      final lStart = lineIndex.lineStart(l);
      final lEnd = lineIndex.lineEnd(l);
      _lines.add(sweepSpans(lineRaw[l], lEnd - lStart));
    }

    _dirtyLines.clear();
    _spanCache.clear();
  }

  /// Slices line storage in response to an incremental editing change [e].
  void onEdit(EngineChange e, LineView lines) {
    final targetLines = lines.lineCount;
    final l0 = posOf(lines, e.start).line;
    final delta = targetLines - _lines.length;

    if (delta > 0) {
      final insertIndex = (l0 + 1).clamp(0, _lines.length);
      final newEntries = List.generate(delta, (_) => const <RangeStyle>[]);
      _lines.insertAll(insertIndex, newEntries);
    } else if (delta < 0) {
      final removeCount = -delta;
      final removeIndex = (l0 + 1).clamp(0, _lines.length);
      final actualRemove = removeCount.clamp(0, _lines.length - removeIndex);
      if (actualRemove > 0) {
        _lines.removeRange(removeIndex, removeIndex + actualRemove);
      }
    }

    // Adjust lines list size to exactly match targetLines if boundary hit
    while (_lines.length < targetLines) {
      _lines.add(const []);
    }
    while (_lines.length > targetLines) {
      _lines.removeLast();
    }

    // Mark lines in the editing region dirty
    final newlines = '\n'.allMatches(e.insertedText).length;
    final dirtyEnd = (l0 + newlines + 1).clamp(0, _lines.length);
    for (var i = l0; i <= dirtyEnd && i < _lines.length; i++) {
      _dirtyLines.add(i);
      if (i < _lines.length) {
        _lines[i] = const [];
      }
    }

    _spanCache.clear();
  }

  /// Returns the styled [TextSpan] for the line at [line] index.
  TextSpan spanFor(int line, String lineText, TextStyle base, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final key = _SpanCacheKey(
      line,
      lineText.hashCode,
      _currentRevision,
      isDark,
    );
    final cached = _spanCache[key];
    if (cached != null) return cached;

    List<RangeStyle> runs;
    if (line < 0 || line >= _lines.length || _dirtyLines.contains(line)) {
      runs = QuickStyler.style(lineText);
    } else {
      runs = _lines[line];
    }

    // Apply overlays if any intersect with this line
    if (_overlays.isNotEmpty) {
      runs = _applyOverlays(line, lineText, runs);
    }

    final children = <InlineSpan>[];
    var cursor = 0;

    for (final run in runs) {
      final runStart = run.start.clamp(0, lineText.length);
      final runEnd = run.end.clamp(0, lineText.length);

      if (runStart > cursor) {
        children.add(
          TextSpan(text: lineText.substring(cursor, runStart), style: base),
        );
      }

      if (runEnd > runStart) {
        var style = base;
        for (final token in run.tokens) {
          style = style.merge(styleFor(token, theme, base));
        }
        children.add(
          TextSpan(text: lineText.substring(runStart, runEnd), style: style),
        );
      }
      cursor = runEnd;
    }

    if (cursor < lineText.length) {
      children.add(TextSpan(text: lineText.substring(cursor), style: base));
    }

    final result = TextSpan(style: base, children: children);
    _spanCache[key] = result;
    return result;
  }

  /// Returns `'code'` if the line contains codeBlock, mathBlock, or frontmatter tokens.
  String? lineKind(int line) {
    if (line < 0 || line >= _lines.length) return null;
    for (final run in _lines[line]) {
      for (final t in run.tokens) {
        if (t == SourceToken.codeBlock ||
            t == SourceToken.mathBlock ||
            t == SourceToken.frontmatter) {
          return 'code';
        }
      }
    }
    return null;
  }

  List<RangeStyle> _applyOverlays(
    int line,
    String lineText,
    List<RangeStyle> baseRuns,
  ) {
    // If overlays exist, convert baseRuns + overlays to raw spans and resweep
    final raw = <RawSpan>[];
    for (final r in baseRuns) {
      for (final t in r.tokens) {
        raw.add(RawSpan(r.start, r.end, t));
      }
    }

    for (final o in _overlays) {
      // Overlays are in document coordinates; check line intersection
      // For simple line-local overlays:
      if (o.start < lineText.length && o.end > 0) {
        final start = o.start.clamp(0, lineText.length);
        final end = o.end.clamp(0, lineText.length);
        if (start < end) {
          raw.add(RawSpan(start, end, o.token));
        }
      }
    }

    return sweepSpans(raw, lineText.length);
  }
}
