// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_index/tephra_index.dart';

import '../engine/search_match.dart';
import '../parser/search_expr.dart';
import 'note_doc.dart';

/// Result of evaluating a [SearchExpr] against a [NoteDoc].
final class MatchOutcome {
  const MatchOutcome({required this.matched, required this.matches});

  final bool matched;
  final List<SearchMatch> matches;
}

/// Evaluates [expr] against [doc] according to Obsidian search semantics.
MatchOutcome evaluate(
  SearchExpr expr,
  NoteDoc doc, {
  required bool caseSensitive,
}) {
  final outcome = _eval(
    expr,
    doc,
    caseSensitive: caseSensitive,
    fileScope: true,
    collectMatches: true,
    regionStart: 0,
    regionEnd: doc.text.length,
  );

  if (!outcome.matched) {
    return const MatchOutcome(matched: false, matches: []);
  }

  // De-duplicate, sort by start offset, cap at 100
  final uniqueMatches = <SearchMatch>[];
  final seen = <(int line, int start, int end, bool inFileName)>{};
  for (final m in outcome.matches) {
    if (seen.add((m.line, m.start, m.end, m.inFileName))) {
      uniqueMatches.add(m);
    }
  }

  uniqueMatches.sort((a, b) {
    if (a.inFileName != b.inFileName) {
      return a.inFileName ? -1 : 1;
    }
    return a.start.compareTo(b.start);
  });

  final capped = uniqueMatches.take(100).toList();
  return MatchOutcome(matched: true, matches: capped);
}

MatchOutcome _eval(
  SearchExpr expr,
  NoteDoc doc, {
  required bool caseSensitive,
  required bool fileScope,
  required bool collectMatches,
  required int regionStart,
  required int regionEnd,
}) {
  switch (expr) {
    case EmptyExpr():
      return const MatchOutcome(matched: true, matches: []);

    case TermExpr(:final text):
    case PhraseExpr(:final text):
      if (text.isEmpty) {
        return const MatchOutcome(matched: true, matches: []);
      }

      final matches = <SearchMatch>[];
      final regionText = doc.text.substring(regionStart, regionEnd);
      final pattern = RegExp(
        RegExp.escape(text),
        caseSensitive: caseSensitive,
        unicode: true,
      );

      for (final m in pattern.allMatches(regionText)) {
        if (!collectMatches) {
          return const MatchOutcome(matched: true, matches: []);
        }
        final matchStart = regionStart + m.start;
        final matchEnd = regionStart + m.end;
        final line = doc.lines.lineOf(matchStart);
        final lineStart = doc.lines.lineStart(line);
        final lineText = doc.lines.lineText(doc.text, line);
        final mStartInLine = matchStart - lineStart;
        final mEndInLine =
            min(matchEnd, lineStart + lineText.length) - lineStart;
        final snippet = makeSnippet(lineText, mStartInLine, mEndInLine.toInt());

        matches.add(
          SearchMatch(
            line: line,
            start: matchStart,
            end: matchEnd,
            snippet: snippet.text,
            snippetStart: snippet.start,
            snippetEnd: snippet.end,
            inFileName: false,
          ),
        );
      }

      // File-name fallback when allowed
      if (fileScope) {
        final fileName = doc.path.name;
        final fileMatches = pattern.allMatches(fileName);
        for (final m in fileMatches) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          matches.add(
            SearchMatch(
              line: -1,
              start: 0,
              end: 0,
              snippet: fileName,
              snippetStart: m.start,
              snippetEnd: m.end,
              inFileName: true,
            ),
          );
        }
      }

      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case RegexExpr(:final pattern, :final flags):
      final re = RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );

      final matches = <SearchMatch>[];
      final regionText = doc.text.substring(regionStart, regionEnd);
      for (final m in re.allMatches(regionText)) {
        if (!collectMatches) {
          return const MatchOutcome(matched: true, matches: []);
        }
        final matchStart = regionStart + m.start;
        final matchEnd = regionStart + m.end;
        final line = doc.lines.lineOf(matchStart);
        final lineStart = doc.lines.lineStart(line);
        final lineText = doc.lines.lineText(doc.text, line);
        final mStartInLine = matchStart - lineStart;
        final mEndInLine =
            min(matchEnd, lineStart + lineText.length) - lineStart;
        final snippet = makeSnippet(lineText, mStartInLine, mEndInLine.toInt());

        matches.add(
          SearchMatch(
            line: line,
            start: matchStart,
            end: matchEnd,
            snippet: snippet.text,
            snippetStart: snippet.start,
            snippetEnd: snippet.end,
            inFileName: false,
          ),
        );
      }

      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case NotExpr(:final child):
      final inner = _eval(
        child,
        doc,
        caseSensitive: caseSensitive,
        fileScope: fileScope,
        collectMatches: false,
        regionStart: regionStart,
        regionEnd: regionEnd,
      );
      return MatchOutcome(matched: !inner.matched, matches: const []);

    case AndExpr(:final children):
      final allMatches = <SearchMatch>[];
      for (final c in children) {
        final inner = _eval(
          c,
          doc,
          caseSensitive: caseSensitive,
          fileScope: fileScope,
          collectMatches: collectMatches,
          regionStart: regionStart,
          regionEnd: regionEnd,
        );
        if (!inner.matched) {
          return const MatchOutcome(matched: false, matches: []);
        }
        allMatches.addAll(inner.matches);
      }
      return MatchOutcome(matched: true, matches: allMatches);

    case OrExpr(:final children):
      final allMatches = <SearchMatch>[];
      var anyMatched = false;
      for (final c in children) {
        final inner = _eval(
          c,
          doc,
          caseSensitive: caseSensitive,
          fileScope: fileScope,
          collectMatches: collectMatches,
          regionStart: regionStart,
          regionEnd: regionEnd,
        );
        if (inner.matched) {
          anyMatched = true;
          allMatches.addAll(inner.matches);
        }
      }
      return MatchOutcome(matched: anyMatched, matches: allMatches);

    case OperatorExpr(:final op, :final value):
      return _evalOperator(
        op,
        value,
        doc,
        caseSensitive: caseSensitive,
        fileScope: fileScope,
        collectMatches: collectMatches,
        regionStart: regionStart,
        regionEnd: regionEnd,
      );

    case PropertyExpr(:final name, :final value):
      return _evalProperty(name, value, doc, caseSensitive: caseSensitive);
  }
}

MatchOutcome _evalOperator(
  SearchOperator op,
  SearchExpr value,
  NoteDoc doc, {
  required bool caseSensitive,
  required bool fileScope,
  required bool collectMatches,
  required int regionStart,
  required int regionEnd,
}) {
  switch (op) {
    case SearchOperator.content:
      return _eval(
        value,
        doc,
        caseSensitive: caseSensitive,
        fileScope: false,
        collectMatches: collectMatches,
        regionStart: regionStart,
        regionEnd: regionEnd,
      );

    case SearchOperator.file:
      return _evalStringTarget(
        value,
        doc.path.name,
        caseSensitive: caseSensitive,
        collectMatches: collectMatches,
        targetDescription: doc.path.name,
      );

    case SearchOperator.path:
      return _evalStringTarget(
        value,
        doc.path.value,
        caseSensitive: caseSensitive,
        collectMatches: collectMatches,
        targetDescription: doc.path.value,
      );

    case SearchOperator.tag:
      final rawTag = value is TermExpr
          ? value.text
          : value is PhraseExpr
          ? value.text
          : '';
      var targetTag = rawTag.trim();
      if (targetTag.startsWith('#')) {
        targetTag = targetTag.substring(1);
      }

      if (targetTag.isEmpty) {
        if (doc.lowerTags.isEmpty) {
          return const MatchOutcome(matched: false, matches: []);
        }
        return MatchOutcome(
          matched: true,
          matches: collectMatches
              ? [
                  SearchMatch(
                    line: 0,
                    start: 0,
                    end: 0,
                    snippet: doc.path.name,
                    snippetStart: 0,
                    snippetEnd: 0,
                  ),
                ]
              : const [],
        );
      }

      final xLower = targetTag.toLowerCase();
      final prefix = '$xLower/';
      final matchedTag = doc.lowerTags.any(
        (t) => t == xLower || t.startsWith(prefix),
      );

      if (!matchedTag) {
        return const MatchOutcome(matched: false, matches: []);
      }

      if (!collectMatches) {
        return const MatchOutcome(matched: true, matches: []);
      }

      // Find inline occurrence of #targetTag if possible
      final matches = <SearchMatch>[];
      final tagPattern = RegExp(
        r'#' + RegExp.escape(targetTag) + r'(\/[a-zA-Z0-9_\-\/]+)?',
        caseSensitive: false,
      );
      for (final m in tagPattern.allMatches(doc.text)) {
        final line = doc.lines.lineOf(m.start);
        final lineStart = doc.lines.lineStart(line);
        final lineText = doc.lines.lineText(doc.text, line);
        final sStart = m.start - lineStart;
        final sEnd = min(m.end, lineStart + lineText.length) - lineStart;
        final snippet = makeSnippet(lineText, sStart, sEnd.toInt());
        matches.add(
          SearchMatch(
            line: line,
            start: m.start,
            end: m.end,
            snippet: snippet.text,
            snippetStart: snippet.start,
            snippetEnd: snippet.end,
          ),
        );
      }

      if (matches.isEmpty) {
        matches.add(
          SearchMatch(
            line: 0,
            start: 0,
            end: 0,
            snippet: doc.path.name,
            snippetStart: 0,
            snippetEnd: 0,
          ),
        );
      }

      return MatchOutcome(matched: true, matches: matches);

    case SearchOperator.task:
    case SearchOperator.taskTodo:
    case SearchOperator.taskDone:
      final matches = <SearchMatch>[];
      for (final t in doc.tasks) {
        if (op == SearchOperator.taskTodo && t.statusChar != ' ') continue;
        if (op == SearchOperator.taskDone && t.statusChar == ' ') continue;

        if (value is EmptyExpr ||
            (value is TermExpr && value.text.isEmpty) ||
            (value is PhraseExpr && value.text.isEmpty)) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          final line = doc.lines.lineOf(t.start);
          final lineText = doc.lines.lineText(doc.text, line);
          final snippet = makeSnippet(lineText, 0, min(lineText.length, 5));
          matches.add(
            SearchMatch(
              line: line,
              start: t.start,
              end: t.end,
              snippet: snippet.text,
              snippetStart: snippet.start,
              snippetEnd: snippet.end,
            ),
          );
          continue;
        }

        // Evaluate value against task text
        final matched = _evalStringTargetMatch(value, t.text, caseSensitive);
        if (matched) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          final line = doc.lines.lineOf(t.start);
          final lineStart = doc.lines.lineStart(line);
          final lineText = doc.lines.lineText(doc.text, line);
          final mStartInLine = max(0, t.start - lineStart);
          final mEndInLine = min(lineText.length, t.end - lineStart);
          final snippet = makeSnippet(lineText, mStartInLine, mEndInLine);
          matches.add(
            SearchMatch(
              line: line,
              start: t.start,
              end: t.end,
              snippet: snippet.text,
              snippetStart: snippet.start,
              snippetEnd: snippet.end,
            ),
          );
        }
      }
      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case SearchOperator.line:
      final matches = <SearchMatch>[];
      for (var i = 0; i < doc.lines.lineCount; i++) {
        final lStart = doc.lines.lineStart(i);
        final lEnd = doc.lines.lineEnd(i);
        if (lStart < regionStart || lEnd > regionEnd) continue;

        final outcome = _eval(
          value,
          doc,
          caseSensitive: caseSensitive,
          fileScope: false,
          collectMatches: collectMatches,
          regionStart: lStart,
          regionEnd: lEnd,
        );

        if (outcome.matched) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          matches.addAll(outcome.matches);
        }
      }
      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case SearchOperator.block:
      final matches = <SearchMatch>[];
      for (final (bStart, bEnd) in doc.blockRanges) {
        if (bStart < regionStart || bEnd > regionEnd) continue;

        final outcome = _eval(
          value,
          doc,
          caseSensitive: caseSensitive,
          fileScope: false,
          collectMatches: collectMatches,
          regionStart: bStart,
          regionEnd: bEnd,
        );

        if (outcome.matched) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          matches.addAll(outcome.matches);
        }
      }
      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case SearchOperator.section:
      final matches = <SearchMatch>[];
      for (final (sStart, sEnd) in doc.sectionRanges) {
        if (sStart < regionStart || sEnd > regionEnd) continue;

        final outcome = _eval(
          value,
          doc,
          caseSensitive: caseSensitive,
          fileScope: false,
          collectMatches: collectMatches,
          regionStart: sStart,
          regionEnd: sEnd,
        );

        if (outcome.matched) {
          if (!collectMatches) {
            return const MatchOutcome(matched: true, matches: []);
          }
          matches.addAll(outcome.matches);
        }
      }
      return MatchOutcome(matched: matches.isNotEmpty, matches: matches);

    case SearchOperator.matchCase:
      return _eval(
        value,
        doc,
        caseSensitive: true,
        fileScope: fileScope,
        collectMatches: collectMatches,
        regionStart: regionStart,
        regionEnd: regionEnd,
      );

    case SearchOperator.ignoreCase:
      return _eval(
        value,
        doc,
        caseSensitive: false,
        fileScope: fileScope,
        collectMatches: collectMatches,
        regionStart: regionStart,
        regionEnd: regionEnd,
      );
  }
}

MatchOutcome _evalStringTarget(
  SearchExpr value,
  String text, {
  required bool caseSensitive,
  required bool collectMatches,
  required String targetDescription,
}) {
  final matched = _evalStringTargetMatch(value, text, caseSensitive);
  if (!matched) {
    return const MatchOutcome(matched: false, matches: []);
  }

  if (!collectMatches) {
    return const MatchOutcome(matched: true, matches: []);
  }

  return MatchOutcome(
    matched: true,
    matches: [
      SearchMatch(
        line: -1,
        start: 0,
        end: 0,
        snippet: targetDescription,
        snippetStart: 0,
        snippetEnd: targetDescription.length,
        inFileName: true,
      ),
    ],
  );
}

bool _evalStringTargetMatch(SearchExpr expr, String text, bool caseSensitive) {
  switch (expr) {
    case EmptyExpr():
      return true;
    case TermExpr(:final text):
    case PhraseExpr(:final text):
      if (text.isEmpty) return true;
      if (caseSensitive) {
        return text.contains(text);
      }
      return text.toLowerCase().contains(text.toLowerCase());
    case RegexExpr(:final pattern, :final flags):
      final re = RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );
      return re.hasMatch(text);
    case AndExpr(:final children):
      return children.every(
        (c) => _evalStringTargetMatch(c, text, caseSensitive),
      );
    case OrExpr(:final children):
      return children.any(
        (c) => _evalStringTargetMatch(c, text, caseSensitive),
      );
    case NotExpr(:final child):
      return !_evalStringTargetMatch(child, text, caseSensitive);
    default:
      return false;
  }
}

MatchOutcome _evalProperty(
  String name,
  PropertyValue value,
  NoteDoc doc, {
  required bool caseSensitive,
}) {
  final nameLower = name.toLowerCase();
  Object? propVal;
  var hasKey = false;
  for (final entry in doc.frontmatter.entries) {
    if (entry.key.toLowerCase() == nameLower) {
      hasKey = true;
      propVal = entry.value;
      break;
    }
  }

  if (!hasKey) {
    return const MatchOutcome(matched: false, matches: []);
  }

  switch (value) {
    case PropertyExists():
      return MatchOutcome(
        matched: true,
        matches: [
          SearchMatch(
            line: 0,
            start: 0,
            end: 0,
            snippet: doc.path.name,
            snippetStart: 0,
            snippetEnd: 0,
          ),
        ],
      );

    case PropertyIsEmpty():
      final isEmpty =
          propVal == null ||
          propVal == '' ||
          (propVal is List && propVal.isEmpty);
      if (isEmpty) {
        return MatchOutcome(
          matched: true,
          matches: [
            SearchMatch(
              line: 0,
              start: 0,
              end: 0,
              snippet: doc.path.name,
              snippetStart: 0,
              snippetEnd: 0,
            ),
          ],
        );
      }
      return const MatchOutcome(matched: false, matches: []);

    case PropertyMatches(:final expr):
      final items = propVal is List ? propVal : [propVal];
      var matched = false;
      for (final item in items) {
        final str = item == null ? '' : item.toString();
        final itemOutcome = _evalPropertyString(expr, str, caseSensitive);
        if (itemOutcome) {
          matched = true;
          break;
        }
      }

      if (matched) {
        return MatchOutcome(
          matched: true,
          matches: [
            SearchMatch(
              line: 0,
              start: 0,
              end: 0,
              snippet: doc.path.name,
              snippetStart: 0,
              snippetEnd: 0,
            ),
          ],
        );
      }
      return const MatchOutcome(matched: false, matches: []);
  }
}

bool _evalPropertyString(
  SearchExpr expr,
  String targetStr,
  bool caseSensitive,
) {
  switch (expr) {
    case EmptyExpr():
      return true;
    case TermExpr(:final text):
    case PhraseExpr(:final text):
      if (text.isEmpty) return true;
      if (caseSensitive) {
        return targetStr.contains(text);
      }
      return targetStr.toLowerCase().contains(text.toLowerCase());
    case RegexExpr(:final pattern, :final flags):
      final re = RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );
      return re.hasMatch(targetStr);
    case AndExpr(:final children):
      return children.every(
        (c) => _evalPropertyString(c, targetStr, caseSensitive),
      );
    case OrExpr(:final children):
      return children.any(
        (c) => _evalPropertyString(c, targetStr, caseSensitive),
      );
    case NotExpr(:final child):
      return !_evalPropertyString(child, targetStr, caseSensitive);
    default:
      return false;
  }
}
