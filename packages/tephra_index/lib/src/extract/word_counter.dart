// © 2026 Tephra. All rights reserved.

final RegExp _wordRegExp = RegExp(
  r"[\p{L}\p{N}\p{M}][\p{L}\p{N}\p{M}'’_-]*",
  unicode: true,
);

/// Counts words in [text], optionally starting from [startOffset].
int countWords(String text, [int startOffset = 0]) {
  if (startOffset >= text.length) return 0;
  final slice = startOffset > 0 ? text.substring(startOffset) : text;
  return _wordRegExp.allMatches(slice).length;
}
