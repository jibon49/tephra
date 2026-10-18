// © 2026 Tephra. All rights reserved.

/// A single highlight match within a searched note.
final class SearchMatch {
  const SearchMatch({
    required this.line,
    required this.start,
    required this.end,
    required this.snippet,
    required this.snippetStart,
    required this.snippetEnd,
    this.inFileName = false,
  });

  /// 0-based line number of the match, or -1 for a file-name-only match.
  final int line;

  /// Start offset within the note text, or 0 for a file-name-only match.
  final int start;

  /// End offset within the note text, or 0 for a file-name-only match.
  final int end;

  /// Context snippet for display, or the file name for file-name matches.
  final String snippet;

  /// Start offset of the match within [snippet].
  final int snippetStart;

  /// End offset of the match within [snippet].
  final int snippetEnd;

  /// True if this match occurred in the file name rather than content.
  final bool inFileName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchMatch &&
          line == other.line &&
          start == other.start &&
          end == other.end &&
          snippet == other.snippet &&
          snippetStart == other.snippetStart &&
          snippetEnd == other.snippetEnd &&
          inFileName == other.inFileName);

  @override
  int get hashCode => Object.hash(
    line,
    start,
    end,
    snippet,
    snippetStart,
    snippetEnd,
    inFileName,
  );

  @override
  String toString() =>
      'SearchMatch(line: $line, range: [$start, $end], snippet: "$snippet" [$snippetStart, $snippetEnd], file: $inFileName)';
}
