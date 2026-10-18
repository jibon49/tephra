// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// An unlinked occurrence of a note title or alias in another note.
final class UnlinkedMention {
  const UnlinkedMention({
    required this.source,
    required this.start,
    required this.end,
    required this.line,
    required this.matchedText,
    required this.snippet,
    required this.snippetStart,
    required this.snippetEnd,
  });

  final VaultPath source;
  final int start;
  final int end;
  final int line;
  final String matchedText;
  final String snippet;
  final int snippetStart;
  final int snippetEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnlinkedMention &&
          source == other.source &&
          start == other.start &&
          end == other.end &&
          line == other.line &&
          matchedText == other.matchedText &&
          snippet == other.snippet &&
          snippetStart == other.snippetStart &&
          snippetEnd == other.snippetEnd;

  @override
  int get hashCode => Object.hash(
    source,
    start,
    end,
    line,
    matchedText,
    snippet,
    snippetStart,
    snippetEnd,
  );

  @override
  String toString() =>
      'UnlinkedMention(source: ${source.value}, matched: $matchedText, line: $line)';
}
