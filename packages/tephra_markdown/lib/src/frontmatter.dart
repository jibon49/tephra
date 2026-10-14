// © 2026 Tephra. All rights reserved.

import 'package:yaml/yaml.dart';

/// The result of splitting an Obsidian YAML frontmatter block from source text.
final class FrontmatterSplit {
  const FrontmatterSplit({
    required this.start,
    required this.end,
    required this.yaml,
    required this.contentStart,
    required this.bodyStart,
  });

  /// Always 0 (frontmatter must begin at the very start of the file).
  final int start;

  /// UTF-16 offset right after the closing `---` (before trailing spaces and `\n`).
  final int end;

  /// The raw YAML text between the delimiters with its trailing `\n` removed.
  final String yaml;

  /// UTF-16 offset of the first character after the opening `---` line's `\n`.
  final int contentStart;

  /// UTF-16 offset after the closing line's `\n` (or `text.length` if EOF).
  final int bodyStart;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrontmatterSplit &&
          start == other.start &&
          end == other.end &&
          yaml == other.yaml &&
          contentStart == other.contentStart &&
          bodyStart == other.bodyStart;

  @override
  int get hashCode => Object.hash(start, end, yaml, contentStart, bodyStart);

  @override
  String toString() =>
      'FrontmatterSplit(start: $start, end: $end, contentStart: $contentStart, bodyStart: $bodyStart)';
}

bool _isOnlySpacesOrTabs(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c != 0x20 && c != 0x09 && c != 0x0D) return false;
  }
  return true;
}

/// Identifies and extracts YAML frontmatter delimited by `---` lines.
/// Returns null if the text does not begin with a valid frontmatter block.
FrontmatterSplit? splitFrontmatter(String text) {
  final firstNewline = text.indexOf('\n');
  if (firstNewline == -1) return null;

  final firstLine = text.substring(0, firstNewline);
  if (!firstLine.startsWith('---')) return null;
  if (!_isOnlySpacesOrTabs(firstLine.substring(3))) return null;

  final contentStart = firstNewline + 1;
  var pos = contentStart;

  while (pos <= text.length) {
    final nextNewline = text.indexOf('\n', pos);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final line = text.substring(pos, lineEnd);

    if (line.startsWith('---') && _isOnlySpacesOrTabs(line.substring(3))) {
      final closingLineStart = pos;
      final end = pos + 3;
      final String yaml;
      if (closingLineStart == contentStart) {
        yaml = '';
      } else {
        var rawYaml = text.substring(contentStart, closingLineStart);
        if (rawYaml.endsWith('\r\n')) {
          rawYaml = rawYaml.substring(0, rawYaml.length - 2);
        } else if (rawYaml.endsWith('\n')) {
          rawYaml = rawYaml.substring(0, rawYaml.length - 1);
        }
        yaml = rawYaml;
      }

      final bodyStart = nextNewline == -1 ? text.length : nextNewline + 1;
      return FrontmatterSplit(
        start: 0,
        end: end,
        yaml: yaml,
        contentStart: contentStart,
        bodyStart: bodyStart,
      );
    }

    if (nextNewline == -1) break;
    pos = nextNewline + 1;
  }

  return null;
}

/// Decodes raw YAML frontmatter text into a standard Dart Map.
/// Returns null if [yaml] is invalid YAML or does not define a top-level map.
/// Returns an empty map `{}` if empty or comment-only.
Map<String, Object?>? decodeFrontmatterYaml(String yaml) {
  if (yaml.trim().isEmpty) return {};

  final dynamic parsed;
  try {
    parsed = loadYaml(yaml);
  } on YamlException {
    return null;
  } catch (_) {
    return null;
  }

  if (parsed == null) return {};
  if (parsed is! YamlMap && parsed is! Map) return null;

  return _convertMap(parsed as Map<Object?, Object?>);
}

Map<String, Object?> _convertMap(Map<Object?, Object?> raw) {
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    result[entry.key.toString()] = _convertValue(entry.value);
  }
  return result;
}

Object? _convertValue(Object? value) {
  if (value is Map) {
    return _convertMap(value.cast<Object?, Object?>());
  } else if (value is List) {
    return value.map(_convertValue).toList();
  }
  return value;
}
