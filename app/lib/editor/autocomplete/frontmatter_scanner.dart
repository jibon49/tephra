// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:tephra_markdown/tephra_markdown.dart';

/// Range of frontmatter content in a Markdown document.
final class FrontmatterRange {
  const FrontmatterRange({
    required this.contentStart,
    required this.contentEnd,
    this.closeLineStart,
  });

  /// UTF-16 offset of the first character of YAML content (after the opening `---` line).
  final int contentStart;

  /// UTF-16 offset right after the last character of YAML content (excluding closing delimiter).
  final int contentEnd;

  /// UTF-16 offset of the start of the closing `---` line, or `null` if unclosed.
  final int? closeLineStart;

  /// Returns true if [offset] falls inside the frontmatter content.
  bool containsOffset(int offset) {
    if (offset < contentStart) return false;
    if (closeLineStart != null) {
      return offset < closeLineStart!;
    }
    return offset <= contentEnd;
  }

  @override
  String toString() =>
      'FrontmatterRange(start: $contentStart, end: $contentEnd, close: $closeLineStart)';
}

bool _isOnlySpacesOrTabs(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c != 0x20 && c != 0x09 && c != 0x0D) return false;
  }
  return true;
}

/// Identifies the frontmatter range in [text].
///
/// If closed, derived from [splitFrontmatter]. If line 0 is `---` but there is
/// no closing line, the rest of the file counts as frontmatter (for lines >= 1).
FrontmatterRange? frontmatterRange(String text) {
  final split = splitFrontmatter(text);
  if (split != null) {
    final closeLineStart = split.end - 3;
    return FrontmatterRange(
      contentStart: split.contentStart,
      contentEnd: split.contentStart + split.yaml.length,
      closeLineStart: closeLineStart,
    );
  }

  // Unclosed frontmatter check: line 0 starts with `---`
  final firstNewline = text.indexOf('\n');
  if (firstNewline != -1) {
    final firstLine = text.substring(0, firstNewline);
    if (firstLine.startsWith('---') &&
        _isOnlySpacesOrTabs(firstLine.substring(3))) {
      return FrontmatterRange(
        contentStart: firstNewline + 1,
        contentEnd: text.length,
        closeLineStart: null,
      );
    }
  }

  return null;
}

/// Returns the 0-indexed line number containing [offset].
int lineAtOffset(String text, int offset) {
  var line = 0;
  final limit = math.min(offset, text.length);
  for (var i = 0; i < limit; i++) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      line++;
    }
  }
  return line;
}

/// Returns the text of line [lineIndex] without trailing `\r` or `\n`.
String getLine(String text, int lineIndex) {
  var curr = 0;
  var currentLine = 0;
  var lineStart = 0;
  while (curr <= text.length) {
    if (curr == text.length || text.codeUnitAt(curr) == 0x0A) {
      if (currentLine == lineIndex) {
        var end = curr;
        if (end > lineStart && text.codeUnitAt(end - 1) == 0x0D) {
          end--;
        }
        return text.substring(lineStart, end);
      }
      currentLine++;
      lineStart = curr + 1;
    }
    curr++;
  }
  return '';
}

String _unquoteKey(String k) {
  if ((k.startsWith('"') && k.endsWith('"') && k.length >= 2) ||
      (k.startsWith("'") && k.endsWith("'") && k.length >= 2)) {
    return k.substring(1, k.length - 1);
  }
  return k;
}

/// Returns the property key that owns the 0-indexed [line] in [text].
///
/// For `key: value` lines, returns the key itself.
/// For a list item line (`^\s*-\s`), scans upward over lines that are list
/// items, deeper-indented, or blank until a line matching `^([^\s#:][^:]*):\s*$`
/// (a key with no inline value) is found. Quoted keys are unquoted.
String? propertyKeyForLine(String text, FrontmatterRange fm, int line) {
  if (line <= 0) return null;
  final current = getLine(text, line);

  // Check if current line is `key: value`
  final kvMatch = RegExp(r'^([^\s#:][^:]*):(?:\s.*)?$').firstMatch(current);
  if (kvMatch != null) {
    if (!current.trimLeft().startsWith('-')) {
      return _unquoteKey(kvMatch.group(1)!.trim());
    }
  }

  // Check if current line is a list item line (`^\s*-\s`)
  if (RegExp(r'^\s*-\s').hasMatch(current)) {
    for (var l = line - 1; l >= 1; l--) {
      final prev = getLine(text, l);
      final trimmed = prev.trim();
      if (trimmed.isEmpty) continue;

      final keyMatch = RegExp(r'^([^\s#:][^:]*):\s*$').firstMatch(prev);
      if (keyMatch != null && !prev.trimLeft().startsWith('-')) {
        return _unquoteKey(keyMatch.group(1)!.trim());
      }

      // Allow list items or indented continuation lines
      if (RegExp(r'^\s*-\s').hasMatch(prev) ||
          RegExp(r'^\s+\S').hasMatch(prev)) {
        continue;
      }

      return null;
    }
  }

  return null;
}

/// Extracts all top-level property keys (lowercase) present in [fm].
Set<String> extractFrontmatterKeys(String text, FrontmatterRange fm) {
  final keys = <String>{};
  final endOffset = fm.closeLineStart ?? fm.contentEnd;
  final slice = text.substring(
    fm.contentStart,
    math.min(endOffset, text.length),
  );

  final lines = slice.split('\n');
  for (final rawLine in lines) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (line.trim().isEmpty) continue;
    if (line.trimLeft().startsWith('-')) continue;

    final match = RegExp(r'^([^\s#:][^:]*):(?:\s.*)?$').firstMatch(line);
    if (match != null) {
      final key = _unquoteKey(match.group(1)!.trim()).toLowerCase();
      if (key.isNotEmpty) {
        keys.add(key);
      }
    }
  }
  return keys;
}

/// Extracts all existing values (lowercase) under [key] within [fm].
Set<String> extractValuesForProperty(
  String text,
  FrontmatterRange fm,
  String key, {
  required bool inInlineList,
  required int caret,
}) {
  final values = <String>{};
  final keyLower = key.toLowerCase();
  final endOffset = fm.closeLineStart ?? fm.contentEnd;
  final slice = text.substring(
    fm.contentStart,
    math.min(endOffset, text.length),
  );

  final lines = slice.split('\n');
  var currentKey = '';
  var insideMatchingKey = false;

  for (final rawLine in lines) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (line.trim().isEmpty) continue;

    if (!line.trimLeft().startsWith('-')) {
      final match = RegExp(r'^([^\s#:][^:]*):(?:\s.*)?$').firstMatch(line);
      if (match != null) {
        currentKey = _unquoteKey(match.group(1)!.trim()).toLowerCase();
        insideMatchingKey = currentKey == keyLower;

        // Check if inline list
        final restMatch = RegExp(r'^[^:]+:[ \t]+\[(.*)\]?').firstMatch(line);
        if (insideMatchingKey && restMatch != null) {
          final inside = restMatch.group(1)!;
          final parts = inside.split(',');
          for (final part in parts) {
            var v = part.trim();
            if ((v.startsWith('"') && v.endsWith('"') && v.length >= 2) ||
                (v.startsWith("'") && v.endsWith("'") && v.length >= 2)) {
              v = v.substring(1, v.length - 1);
            }
            if (v.isNotEmpty) values.add(v.toLowerCase());
          }
        }
        continue;
      }
    }

    if (insideMatchingKey && RegExp(r'^\s*-\s+(.*)$').hasMatch(line)) {
      final itemMatch = RegExp(r'^\s*-\s+(.*)$').firstMatch(line)!;
      var v = itemMatch.group(1)!.trim();
      if ((v.startsWith('"') && v.endsWith('"') && v.length >= 2) ||
          (v.startsWith("'") && v.endsWith("'") && v.length >= 2)) {
        v = v.substring(1, v.length - 1);
      }
      if (v.isNotEmpty) values.add(v.toLowerCase());
    }
  }

  return values;
}
