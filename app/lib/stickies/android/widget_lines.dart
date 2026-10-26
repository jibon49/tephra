// © 2026 Tephra. All rights reserved.

/// Kind of line rendered inside an Android sticky widget.
enum WidgetLineKind { text, task, heading, bullet }

/// A single rendered line within a single-sticky home screen widget.
final class WidgetLine {
  const WidgetLine({
    required this.text,
    required this.kind,
    this.checked = false,
    required this.sourceLine,
  });

  factory WidgetLine.fromJson(Map<String, Object?> json) {
    return WidgetLine(
      text: json['t'] as String? ?? '',
      kind: WidgetLineKind.values.byName(json['k'] as String? ?? 'text'),
      checked: json['c'] as bool? ?? false,
      sourceLine: (json['l'] as num?)?.toInt() ?? 0,
    );
  }

  /// The displayed line text with markdown formatting stripped.
  final String text;

  /// Kind of widget line.
  final WidgetLineKind kind;

  /// Checked state when [kind] is [WidgetLineKind.task].
  final bool checked;

  /// 0-based line index in the source note text.
  final int sourceLine;

  Map<String, Object?> toJson() => {
    't': text,
    'k': kind.name,
    'c': checked,
    'l': sourceLine,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetLine &&
          text == other.text &&
          kind == other.kind &&
          checked == other.checked &&
          sourceLine == other.sourceLine;

  @override
  int get hashCode => Object.hash(text, kind, checked, sourceLine);

  @override
  String toString() =>
      'WidgetLine(text: $text, kind: $kind, checked: $checked, sourceLine: $sourceLine)';
}

/// Image extensions recognized for wikilink embeds.
const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.svg',
  '.webp',
  '.bmp',
  '.ico',
};

/// Strips markdown inline markup and converts embeds/wikilinks/links into clean text.
String stripInlineMarkup(String text) {
  var s = text;

  // Drop inline comments %% ... %%
  s = s.replaceAll(RegExp(r'%%.*?%%'), '');

  // Embeds: ![[path|alt]] or ![[path]]
  s = s.replaceAllMapped(RegExp(r'!\[\[(.*?)\]\]'), (match) {
    final raw = match.group(1) ?? '';
    final target = raw.contains('|') ? raw.split('|').first.trim() : raw.trim();
    final dotIndex = target.lastIndexOf('.');
    if (dotIndex != -1) {
      final ext = target.substring(dotIndex).toLowerCase();
      if (_imageExtensions.contains(ext)) {
        return '[image]';
      }
    }
    return '[file]';
  });

  // Markdown image: ![alt](url)
  s = s.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '[image]');

  // Wikilinks: [[target|alias]] -> alias, [[target]] -> target
  s = s.replaceAllMapped(RegExp(r'\[\[(.*?)\]\]'), (match) {
    final raw = match.group(1) ?? '';
    if (raw.contains('|')) {
      final parts = raw.split('|');
      final alias = parts.sublist(1).join('|').trim();
      return alias.isNotEmpty ? alias : parts.first.trim();
    }
    return raw.trim();
  });

  // Markdown links: [text](url) -> text
  s = s.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) {
    return match.group(1) ?? '';
  });

  // Inline code: `code` -> code
  s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) {
    return match.group(1) ?? '';
  });

  // Bold / italic / strikethrough / highlight markers
  // Order matters: double markers first
  s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'==([^=]+)=='), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m.group(1) ?? '');

  // Clean remaining isolated markers if any
  s = s.replaceAll(RegExp(r'[*_~=]{2,}'), '');

  return s.trim();
}

/// Extracts up to [maxLines] widget lines from markdown note text.
List<WidgetLine> widgetLinesFromMarkdown(String noteText, {int maxLines = 10}) {
  final lines = noteText.split('\n');
  final result = <WidgetLine>[];

  var startIndex = 0;
  // Skip YAML frontmatter if present at the very beginning
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        startIndex = i + 1;
        break;
      }
    }
  }

  var inComment = false;
  var inCodeBlock = false;

  final taskRegex = RegExp(r'^(\s*)(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s*(.*)$');
  final bulletRegex = RegExp(r'^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$');
  final headingRegex = RegExp(r'^(#{1,6})\s+(.*)$');
  final codeFenceRegex = RegExp(r'^\s*(```|~~~)');

  for (var i = startIndex; i < lines.length; i++) {
    if (result.length >= maxLines) break;

    var line = lines[i];

    // Multi-line comment tracking
    if (inComment) {
      final endCommentIdx = line.indexOf('%%');
      if (endCommentIdx != -1) {
        inComment = false;
        line = line.substring(endCommentIdx + 2);
      } else {
        continue;
      }
    }

    if (line.contains('%%')) {
      // Check if starts comment that doesn't close on this line
      final count = RegExp(r'%%').allMatches(line).length;
      if (count % 2 == 1) {
        inComment = true;
        line = line.substring(0, line.indexOf('%%'));
      } else {
        line = line.replaceAll(RegExp(r'%%.*?%%'), '');
      }
    }

    // Code fence tracking
    if (codeFenceRegex.hasMatch(line)) {
      if (!inCodeBlock) {
        inCodeBlock = true;
        // Check next lines for the first code line
        for (var j = i + 1; j < lines.length; j++) {
          if (codeFenceRegex.hasMatch(lines[j])) {
            i = j;
            inCodeBlock = false;
            break;
          }
          final trimmedCode = lines[j].trim();
          if (trimmedCode.isNotEmpty) {
            var text = trimmedCode;
            if (text.length > 200) text = text.substring(0, 200);
            result.add(
              WidgetLine(text: text, kind: WidgetLineKind.text, sourceLine: j),
            );
            // Skip the rest of the code block until closing fence
            for (var k = j + 1; k < lines.length; k++) {
              if (codeFenceRegex.hasMatch(lines[k])) {
                i = k;
                inCodeBlock = false;
                break;
              }
            }
            break;
          }
        }
      } else {
        inCodeBlock = false;
      }
      continue;
    }

    if (inCodeBlock) {
      continue;
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // 1. Task check
    final taskMatch = taskRegex.firstMatch(line);
    if (taskMatch != null) {
      final indent = taskMatch.group(1) ?? '';
      final level = (indent.replaceAll('\t', '  ').length / 2).floor();
      final indentPrefix = '  ' * level;
      final isChecked = (taskMatch.group(2) ?? '').toLowerCase() == 'x';
      final rawText = taskMatch.group(3) ?? '';
      final cleanedText = stripInlineMarkup(rawText);
      var text = '$indentPrefix$cleanedText';
      if (text.length > 200) text = text.substring(0, 200);

      result.add(
        WidgetLine(
          text: text,
          kind: WidgetLineKind.task,
          checked: isChecked,
          sourceLine: i,
        ),
      );
      continue;
    }

    // 2. Bullet list check
    final bulletMatch = bulletRegex.firstMatch(line);
    if (bulletMatch != null) {
      final indent = bulletMatch.group(1) ?? '';
      final level = (indent.replaceAll('\t', '  ').length / 2).floor();
      final indentPrefix = '  ' * level;
      final rawText = bulletMatch.group(2) ?? '';
      final cleanedText = stripInlineMarkup(rawText);
      var text = '$indentPrefix• $cleanedText';
      if (text.length > 200) text = text.substring(0, 200);

      result.add(
        WidgetLine(text: text, kind: WidgetLineKind.bullet, sourceLine: i),
      );
      continue;
    }

    // 3. Heading check
    final headingMatch = headingRegex.firstMatch(trimmed);
    if (headingMatch != null) {
      final rawText = headingMatch.group(2) ?? '';
      var text = stripInlineMarkup(rawText);
      if (text.length > 200) text = text.substring(0, 200);

      result.add(
        WidgetLine(text: text, kind: WidgetLineKind.heading, sourceLine: i),
      );
      continue;
    }

    // 4. Regular text
    var text = stripInlineMarkup(trimmed);
    if (text.isEmpty) continue;
    if (text.length > 200) text = text.substring(0, 200);

    result.add(
      WidgetLine(text: text, kind: WidgetLineKind.text, sourceLine: i),
    );
  }

  return result;
}
