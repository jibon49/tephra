// © 2026 Tephra. All rights reserved.

const _specialStarts = '-?:,[]{}#&*!|>\'"%@`';

const _booleanOrNullLiterals = {
  'true',
  'false',
  'yes',
  'no',
  'on',
  'off',
  'null',
  '~',
};

final _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');

/// Formats a string scalar [v] for insertion into YAML frontmatter.
///
/// Returns [v] plain when it is safe to emit unquoted. Otherwise returns
/// a double-quoted string with `\` and `"` escaped.
String yamlScalarForInsert(String v, {String? keyType}) {
  if (_needsQuotes(v, keyType)) {
    final escaped = v
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return '"$escaped"';
  }
  return v;
}

bool _needsQuotes(String v, String? keyType) {
  if (v.isEmpty) return true;

  // Leading or trailing whitespace
  if (v.startsWith(' ') ||
      v.startsWith('\t') ||
      v.endsWith(' ') ||
      v.endsWith('\t')) {
    return true;
  }

  // Starts with any of - ? : , [ ] { } # & * ! | > ' " % @ `
  final first = v[0];
  if (_specialStarts.contains(first)) {
    return true;
  }

  // Contains `: ` or ` #`
  if (v.contains(': ') || v.contains(' #')) {
    return true;
  }

  // Quotes inside the string
  if (v.contains('"')) {
    return true;
  }

  // Equals (case-insensitively) true, false, yes, no, on, off, null, ~
  if (_booleanOrNullLiterals.contains(v.toLowerCase())) {
    return true;
  }

  // Parses as a number (num.tryParse) and the key's index type is not number
  if (num.tryParse(v) != null && keyType != 'number') {
    return true;
  }

  // Looks like a date (^\d{4}-\d{2}-\d{2}) and the key's type is text
  if (_dateRegex.hasMatch(v) && keyType == 'text') {
    return true;
  }

  return false;
}
