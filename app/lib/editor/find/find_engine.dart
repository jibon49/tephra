// © 2026 Tephra. All rights reserved.

import '../edit_operation.dart';
import 'find_options.dart';

/// Single match found in a document.
final class FindMatch {
  const FindMatch({
    required this.start,
    required this.end,
    this.groups = const [],
  });

  final int start;
  final int end;
  final List<String?> groups;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FindMatch &&
          start == other.start &&
          end == other.end &&
          _listEquals(groups, other.groups);

  @override
  int get hashCode => Object.hash(start, end, Object.hashAll(groups));

  @override
  String toString() => 'FindMatch($start..$end, groups: $groups)';

  static bool _listEquals(List<String?> a, List<String?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Result of a search across a text document.
final class FindResult {
  const FindResult({
    this.matches = const [],
    this.truncated = false,
    this.error,
  });

  final List<FindMatch> matches;
  final bool truncated;
  final String? error;
}

/// Finds all occurrences matching [o] in [text].
FindResult findAll(String text, FindOptions o, {int limit = 10000}) {
  if (o.query.isEmpty) return const FindResult();

  var pattern = o.regex ? o.query : RegExp.escape(o.query);
  if (o.wholeWord) {
    pattern = '(?<![\\p{L}\\p{N}\\p{M}_])(?:$pattern)(?![\\p{L}\\p{N}\\p{M}_])';
  }

  final RegExp regex;
  try {
    regex = RegExp(
      pattern,
      caseSensitive: o.matchCase,
      unicode: true,
      multiLine: true,
    );
  } on FormatException catch (e) {
    return FindResult(error: e.message);
  }

  final matches = <FindMatch>[];
  var truncated = false;

  for (final m in regex.allMatches(text)) {
    // Skip zero-length regex matches
    if (m.end == m.start) continue;

    final groups = <String?>[];
    for (var i = 0; i <= m.groupCount; i++) {
      groups.add(m.group(i));
    }

    matches.add(FindMatch(start: m.start, end: m.end, groups: groups));
    if (matches.length >= limit) {
      truncated = true;
      break;
    }
  }

  return FindResult(matches: matches, truncated: truncated);
}

/// Expands a replacement [template] using capture groups from [m].
String expandReplacement(FindMatch m, String template, {required bool regex}) {
  if (!regex) return template;

  final sb = StringBuffer();
  var i = 0;

  while (i < template.length) {
    final ch = template[i];
    if (ch == r'$' && i + 1 < template.length) {
      final next = template[i + 1];
      if (next == r'$') {
        sb.write(r'$');
        i += 2;
      } else if (next == '&' || next == '0') {
        sb.write(m.groups.isNotEmpty ? (m.groups[0] ?? '') : '');
        i += 2;
      } else {
        final groupNum = int.tryParse(next);
        if (groupNum != null && groupNum >= 1 && groupNum <= 9) {
          if (groupNum < m.groups.length) {
            sb.write(m.groups[groupNum] ?? '');
          }
          i += 2;
        } else {
          sb.write(ch);
          i++;
        }
      }
    } else {
      sb.write(ch);
      i++;
    }
  }

  return sb.toString();
}

/// Builds non-overlapping [EditOperation] list replacing all [matches].
List<EditOperation> replaceAllOps(
  String text,
  List<FindMatch> matches,
  String replaceText, {
  required bool regex,
}) {
  final ops = <EditOperation>[];
  for (final m in matches) {
    final rep = expandReplacement(m, replaceText, regex: regex);
    ops.add(EditOperation(m.start, m.end, rep));
  }
  return ops;
}
