// © 2026 Tephra. All rights reserved.

final _punctOrSymbol = RegExp(r'[\p{P}\p{S}]', unicode: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);

/// Returns true if [cp] is an ASCII punctuation character:
/// `!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~`.
bool isAsciiPunctuation(int cp) {
  return (cp >= 33 && cp <= 47) ||
      (cp >= 58 && cp <= 64) ||
      (cp >= 91 && cp <= 96) ||
      (cp >= 123 && cp <= 126);
}

/// Returns true if [cp] is Unicode whitespace (Unicode `Zs` category, or
/// tab, LF, FF, CR). U+0085 (NEL) is explicitly excluded.
bool isUnicodeWhitespace(int cp) {
  if (cp == 0x20 || cp == 0x09 || cp == 0x0A || cp == 0x0C || cp == 0x0D) {
    return true;
  }
  if (cp == 0x00A0 ||
      cp == 0x1680 ||
      cp == 0x202F ||
      cp == 0x205F ||
      cp == 0x3000) {
    return true;
  }
  if (cp >= 0x2000 && cp <= 0x200A) {
    return true;
  }
  return false;
}

/// Returns true if [cp] is an ASCII punctuation character or belongs to
/// Unicode general category `P` (punctuation) or `S` (symbol).
bool isUnicodePunctuation(int cp) {
  if (isAsciiPunctuation(cp)) return true;
  if (cp < 128) return false;
  return _punctOrSymbol.hasMatch(String.fromCharCode(cp));
}

/// Returns true if [cp] is a letter (`\p{L}`), number (`\p{N}`), or mark (`\p{M}`).
bool isLetterOrDigit(int cp) {
  if ((cp >= 0x30 && cp <= 0x39) ||
      (cp >= 0x41 && cp <= 0x5A) ||
      (cp >= 0x61 && cp <= 0x7A)) {
    return true;
  }
  if (cp < 128) return false;
  return _letterOrDigit.hasMatch(String.fromCharCode(cp));
}

/// CommonMark Unicode case-folding for reference labels:
/// lower-cases and replaces `ß` with `ss`.
String caseFold(String s) {
  return s.toLowerCase().replaceAll('ß', 'ss');
}

/// Normalises reference labels per CommonMark:
/// trims, collapses any whitespace sequence to a single space, and case-folds.
String normalizeLabel(String s) {
  final trimmed = s.trim();
  final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
  return caseFold(collapsed);
}
