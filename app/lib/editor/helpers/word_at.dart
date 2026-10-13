// © 2026 Tephra. All rights reserved.

final _wordCharRegex = RegExp(r'[\p{L}\p{N}\p{M}_]', unicode: true);

bool isWordChar(String char) => _wordCharRegex.hasMatch(char);

/// Returns the `(start, end)` column bounds of the word touching [col] in [line], or `null` if no word touches it.
///
/// A caret at a word boundary touching a word counts as inside it.
(int, int)? wordRangeAt(String line, int col) {
  if (line.isEmpty) return null;

  int? seedIndex;
  if (col < line.length && isWordChar(line[col])) {
    seedIndex = col;
  } else if (col > 0 && col <= line.length && isWordChar(line[col - 1])) {
    seedIndex = col - 1;
  }

  if (seedIndex == null) return null;

  var start = seedIndex;
  while (start > 0 && isWordChar(line[start - 1])) {
    start--;
  }

  var end = seedIndex + 1;
  while (end < line.length && isWordChar(line[end])) {
    end++;
  }

  return (start, end);
}
