// © 2026 Tephra. All rights reserved.

/// A trimmed context snippet around a search hit or unlinked mention match.
final class Snippet {
  const Snippet({required this.text, required this.start, required this.end});

  /// The context text (with optional leading/trailing '…' and trimmed leading space).
  final String text;

  /// Start offset of the match within [text].
  final int start;

  /// End offset of the match within [text].
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snippet &&
          text == other.text &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(text, start, end);

  @override
  String toString() => 'Snippet(text: "$text", start: $start, end: $end)';
}

/// Creates a snippet from [lineText] containing a match at [[matchStart], [matchEnd]).
///
/// Leading whitespace of the line is trimmed (adjusting offsets).
/// If the line fits in [maxLength], returns it whole. Otherwise keeps up to 60 characters
/// before the match and fills the rest after it; adds `'…'` at a cut start and/or end.
Snippet makeSnippet(
  String lineText,
  int matchStart,
  int matchEnd, {
  int maxLength = 160,
}) {
  final trimmedLeft = lineText.trimLeft();
  final leadingSpaces = lineText.length - trimmedLeft.length;

  final mStart = (matchStart - leadingSpaces).clamp(0, trimmedLeft.length);
  final mEnd = (matchEnd - leadingSpaces).clamp(0, trimmedLeft.length);
  final matchLength = mEnd - mStart;

  if (trimmedLeft.length <= maxLength) {
    return Snippet(text: trimmedLeft, start: mStart, end: mEnd);
  }

  final bool cutStart = mStart > 60;
  final String prefix = cutStart ? '…' : '';
  final int startInTrimmed = cutStart ? mStart - 60 : 0;
  final int charsBeforeMatch = mStart - startInTrimmed;

  final int availableAfterMatch = maxLength - charsBeforeMatch - matchLength;

  final bool cutEnd = (trimmedLeft.length - mEnd) > availableAfterMatch;
  final String suffix = cutEnd ? '…' : '';
  final int endInTrimmed = cutEnd
      ? mEnd + availableAfterMatch.clamp(0, trimmedLeft.length - mEnd)
      : trimmedLeft.length;

  final snippetText =
      prefix + trimmedLeft.substring(startInTrimmed, endInTrimmed) + suffix;
  final snippetStart = prefix.length + charsBeforeMatch;
  final snippetEnd = snippetStart + matchLength;

  return Snippet(text: snippetText, start: snippetStart, end: snippetEnd);
}
