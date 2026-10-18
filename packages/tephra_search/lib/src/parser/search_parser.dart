// © 2026 Tephra. All rights reserved.

import 'search_expr.dart';
import 'search_syntax_exception.dart';

/// Hand-written, scannerless recursive descent parser for Obsidian search syntax.
final class SearchParser {
  SearchParser._(
    this._input, {
    this._baseOffset = 0,
    this._isInsideProperty = false,
  });

  final String _input;
  final int _baseOffset;
  final bool _isInsideProperty;
  int _pos = 0;
  bool _isInGroup = false;

  /// Parses [query] into a normalized [SearchExpr] tree.
  static SearchExpr parse(String query) {
    if (query.trim().isEmpty) {
      return const EmptyExpr();
    }
    final parser = SearchParser._(query);
    final expr = parser._parseQuery();
    return parser._normalize(expr);
  }

  SearchExpr _parseQuery() {
    _skipWs();
    if (_pos >= _input.length) {
      return const EmptyExpr();
    }
    final expr = _parseOrExpr();
    _skipWs();
    if (_pos < _input.length) {
      if (_input.codeUnitAt(_pos) == 0x29) {
        throw SearchSyntaxException(
          'Unexpected closing parenthesis',
          _baseOffset + _pos,
        );
      }
      throw SearchSyntaxException(
        'Unexpected trailing character',
        _baseOffset + _pos,
      );
    }
    return expr;
  }

  SearchExpr _parseOrExpr() {
    final children = <SearchExpr>[];
    final first = _parseAndExpr();
    if (first is EmptyExpr && _pos >= _input.length) {
      return first;
    }
    children.add(first);

    while (_pos < _input.length) {
      _skipWs();
      if (_pos >= _input.length) break;
      if (_input.codeUnitAt(_pos) == 0x29) break; // ')'
      if (_isInsideProperty && _input.codeUnitAt(_pos) == 0x5D) break; // ']'

      if (_isOrOperatorAhead(hasLeftOperand: true)) {
        _pos += 2; // consume 'OR'
        _skipWs();
        final right = _parseAndExpr();
        children.add(right);
      } else {
        break;
      }
    }

    if (children.length == 1) {
      return children.first;
    }
    return OrExpr(children);
  }

  SearchExpr _parseAndExpr() {
    final children = <SearchExpr>[];
    while (_pos < _input.length) {
      _skipWs();
      if (_pos >= _input.length) break;

      if (_input.codeUnitAt(_pos) == 0x29) {
        // ')'
        if (!_isInGroup) {
          throw SearchSyntaxException(
            'Unexpected closing parenthesis',
            _baseOffset + _pos,
          );
        }
        break;
      }

      if (_isInsideProperty && _input.codeUnitAt(_pos) == 0x5D) {
        // ']'
        break;
      }

      if (_isOrOperatorAhead(hasLeftOperand: children.isNotEmpty)) {
        break;
      }

      final expr = _parseUnary();
      children.add(expr);
    }

    if (children.isEmpty) {
      return const EmptyExpr();
    }
    if (children.length == 1) {
      return children.first;
    }
    return AndExpr(children);
  }

  SearchExpr _parseUnary() {
    if (_pos < _input.length && _input.codeUnitAt(_pos) == 0x2D) {
      // '-'
      if (_pos + 1 >= _input.length) {
        _pos++;
        return const TermExpr('-');
      }
      final next = _input.codeUnitAt(_pos + 1);
      if (_isWhitespace(next)) {
        _pos++;
        return const TermExpr('-');
      }
      _pos++; // consume '-'
      final inner = _parsePrimary();
      return NotExpr(inner);
    }
    return _parsePrimary();
  }

  SearchExpr _parsePrimary() {
    _skipWs();
    if (_pos >= _input.length) {
      return const EmptyExpr();
    }

    final code = _input.codeUnitAt(_pos);

    if (code == 0x29) {
      // ')'
      throw SearchSyntaxException(
        'Unexpected closing parenthesis',
        _baseOffset + _pos,
      );
    }

    if (code == 0x28) {
      // '('
      return _parseGroup();
    }

    if (code == 0x22) {
      // '"'
      return _parsePhrase();
    }

    if (code == 0x2F) {
      // '/'
      final regex = _tryRegex();
      if (regex != null) {
        return regex;
      }
      return _parseWord();
    }

    if (code == 0x5B && !_isInsideProperty) {
      // '['
      final prop = _tryProperty();
      if (prop != null) {
        return prop;
      }
      return _parseWord();
    }

    final op = _tryOperator();
    if (op != null) {
      return op;
    }

    return _parseWord();
  }

  SearchExpr _parseGroup() {
    final groupStartOffset = _pos;
    _pos++; // consume '('
    _skipWs();
    if (_pos >= _input.length) {
      throw SearchSyntaxException(
        'Unclosed group',
        _baseOffset + groupStartOffset,
      );
    }
    if (_input.codeUnitAt(_pos) == 0x29) {
      // ')'
      throw SearchSyntaxException(
        'Empty group',
        _baseOffset + groupStartOffset,
      );
    }

    final prevInGroup = _isInGroup;
    _isInGroup = true;
    try {
      final inner = _parseOrExpr();
      _skipWs();
      if (_pos >= _input.length || _input.codeUnitAt(_pos) != 0x29) {
        throw SearchSyntaxException(
          'Unclosed group',
          _baseOffset + groupStartOffset,
        );
      }
      _pos++; // consume ')'
      return inner;
    } finally {
      _isInGroup = prevInGroup;
    }
  }

  SearchExpr _parsePhrase() {
    _pos++; // consume '"'
    final sb = StringBuffer();
    while (_pos < _input.length) {
      final ch = _input[_pos];
      if (ch == r'\') {
        if (_pos + 1 < _input.length) {
          final next = _input[_pos + 1];
          if (next == '"') {
            sb.write('"');
            _pos += 2;
            continue;
          } else if (next == r'\') {
            sb.write(r'\');
            _pos += 2;
            continue;
          }
        }
        sb.write(r'\');
        _pos++;
      } else if (ch == '"') {
        _pos++; // consume closing '"'
        return PhraseExpr(sb.toString());
      } else {
        sb.write(ch);
        _pos++;
      }
    }
    return PhraseExpr(sb.toString());
  }

  SearchExpr? _tryRegex() {
    final start = _pos;
    var p = start + 1;
    final patternSb = StringBuffer();
    var closed = false;

    while (p < _input.length) {
      if (_input[p] == r'\') {
        if (p + 1 < _input.length && _input[p + 1] == '/') {
          patternSb.write(r'\/');
          p += 2;
          continue;
        }
        patternSb.write(r'\');
        p++;
        if (p < _input.length) {
          patternSb.write(_input[p]);
          p++;
        }
        continue;
      }
      if (_input[p] == '/') {
        closed = true;
        p++; // past closing '/'
        break;
      }
      patternSb.write(_input[p]);
      p++;
    }

    if (!closed) {
      return null;
    }

    final pattern = patternSb.toString();
    if (pattern.isEmpty) {
      return null;
    }

    final flagsSb = StringBuffer();
    while (p < _input.length) {
      final c = _input[p];
      if (c == 'i' || c == 'm' || c == 's' || c == 'u') {
        flagsSb.write(c);
        p++;
      } else {
        break;
      }
    }
    final flags = flagsSb.toString();

    if (p < _input.length) {
      final next = _input.codeUnitAt(p);
      if (!_isWhitespace(next) && next != 0x29) {
        return null;
      }
    }

    try {
      RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );
    } on FormatException {
      throw SearchSyntaxException(
        'Invalid regular expression',
        _baseOffset + start,
      );
    }

    _pos = p;
    return RegexExpr(pattern, flags);
  }

  SearchExpr? _tryProperty() {
    final start = _pos;
    var p = start + 1;
    var inQuotes = false;
    var closingBracketPos = -1;

    while (p < _input.length) {
      final ch = _input[p];
      if (ch == r'\' && inQuotes && p + 1 < _input.length) {
        p += 2;
        continue;
      }
      if (ch == '"') {
        inQuotes = !inQuotes;
        p++;
        continue;
      }
      if (!inQuotes && ch == ']') {
        closingBracketPos = p;
        break;
      }
      p++;
    }

    if (closingBracketPos == -1) {
      return null;
    }

    final inside = _input.substring(start + 1, closingBracketPos);
    var colonPos = -1;
    var inQ = false;
    for (var i = 0; i < inside.length; i++) {
      if (inside[i] == r'\' && inQ && i + 1 < inside.length) {
        i++;
        continue;
      }
      if (inside[i] == '"') {
        inQ = !inQ;
        continue;
      }
      if (!inQ && inside[i] == ':') {
        colonPos = i;
        break;
      }
    }

    _pos = closingBracketPos + 1;

    if (colonPos == -1) {
      final propName = inside.trim();
      return PropertyExpr(propName, const PropertyExists());
    }

    final propName = inside.substring(0, colonPos).trim();
    final rawBody = inside.substring(colonPos + 1);
    final propBody = rawBody.trim();

    if (propBody.isEmpty || propBody.toLowerCase() == 'null') {
      return PropertyExpr(propName, const PropertyIsEmpty());
    }

    final leadingSpaces = rawBody.length - rawBody.trimLeft().length;
    final bodyStart = start + 1 + (colonPos + 1) + leadingSpaces;

    final nestedParser = SearchParser._(
      propBody,
      baseOffset: _baseOffset + bodyStart,
      isInsideProperty: true,
    );
    final nestedExpr = nestedParser._parseQuery();
    final normalized = nestedParser._normalize(nestedExpr);
    return PropertyExpr(propName, PropertyMatches(normalized));
  }

  SearchExpr? _tryOperator() {
    var p = _pos;
    while (p < _input.length) {
      final code = _input.codeUnitAt(p);
      final isLetter =
          (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
      final isHyphen = code == 0x2D;
      if (isLetter || isHyphen) {
        p++;
      } else {
        break;
      }
    }
    if (p > _pos && p < _input.length && _input.codeUnitAt(p) == 0x3A) {
      final name = _input.substring(_pos, p);
      final op = SearchOperator.tryFromGrammarName(name);
      if (op != null) {
        _pos = p + 1; // consume name and ':'
        return OperatorExpr(op, _parseOperatorValue(op));
      }
    }
    return null;
  }

  SearchExpr _parseOperatorValue(SearchOperator op) {
    if (op == SearchOperator.matchCase || op == SearchOperator.ignoreCase) {
      if (_pos >= _input.length) {
        return const EmptyExpr();
      }
      final code = _input.codeUnitAt(_pos);
      if (_isWhitespace(code) || code == 0x29) {
        return const EmptyExpr();
      }
      return _parsePrimary();
    }

    if (_pos >= _input.length) {
      return const EmptyExpr();
    }

    final code = _input.codeUnitAt(_pos);
    if (_isWhitespace(code) || code == 0x29) {
      return const EmptyExpr();
    }

    if (code == 0x28) {
      return _parseGroup();
    }

    if (code == 0x22) {
      return _parsePhrase();
    }

    if (code == 0x2F) {
      final regex = _tryRegex();
      if (regex != null) {
        return regex;
      }
    }

    final word = _parseWord();
    if (op == SearchOperator.tag &&
        word is TermExpr &&
        word.text.startsWith('#')) {
      return TermExpr(word.text.substring(1));
    }
    return word;
  }

  SearchExpr _parseWord() {
    final start = _pos;
    while (_pos < _input.length) {
      final code = _input.codeUnitAt(_pos);
      if (_isWhitespace(code) || code == 0x28 || code == 0x29) {
        break;
      }
      if (_isInsideProperty && code == 0x5D) {
        break;
      }
      _pos++;
    }
    final text = _input.substring(start, _pos);
    return TermExpr(text);
  }

  bool _isOrOperatorAhead({required bool hasLeftOperand}) {
    if (!hasLeftOperand) return false;
    final start = _pos;
    if (start + 2 > _input.length) return false;
    if (_input.codeUnitAt(start) != 0x4F ||
        _input.codeUnitAt(start + 1) != 0x52) {
      return false;
    }
    if (start + 2 < _input.length) {
      final next = _input.codeUnitAt(start + 2);
      if (!_isWhitespace(next) && next != 0x28 && next != 0x29) {
        return false;
      }
    }
    var p = start + 2;
    while (p < _input.length && _isWhitespace(_input.codeUnitAt(p))) {
      p++;
    }
    if (p >= _input.length) return false;
    if (_input.codeUnitAt(p) == 0x29) return false;
    return true;
  }

  void _skipWs() {
    while (_pos < _input.length && _isWhitespace(_input.codeUnitAt(_pos))) {
      _pos++;
    }
  }

  static bool _isWhitespace(int codeUnit) {
    if (codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D) {
      return true;
    }
    if (codeUnit > 127) {
      final s = String.fromCharCode(codeUnit);
      return s.trim().isEmpty;
    }
    return false;
  }

  SearchExpr _normalize(SearchExpr expr) {
    switch (expr) {
      case EmptyExpr():
      case TermExpr():
      case PhraseExpr():
      case RegexExpr():
        return expr;

      case NotExpr(:final child):
        return NotExpr(_normalize(child));

      case OperatorExpr(:final op, :final value):
        return OperatorExpr(op, _normalize(value));

      case PropertyExpr(:final name, :final value):
        switch (value) {
          case PropertyExists():
          case PropertyIsEmpty():
            return expr;
          case PropertyMatches(:final expr):
            return PropertyExpr(name, PropertyMatches(_normalize(expr)));
        }

      case AndExpr(:final children):
        final flat = <SearchExpr>[];
        for (final c in children) {
          final norm = _normalize(c);
          if (norm is AndExpr) {
            flat.addAll(norm.children);
          } else if (norm is! EmptyExpr) {
            flat.add(norm);
          }
        }
        if (flat.isEmpty) return const EmptyExpr();
        if (flat.length == 1) return flat.first;
        return AndExpr(flat);

      case OrExpr(:final children):
        final flat = <SearchExpr>[];
        for (final c in children) {
          final norm = _normalize(c);
          if (norm is OrExpr) {
            flat.addAll(norm.children);
          } else if (norm is! EmptyExpr) {
            flat.add(norm);
          }
        }
        if (flat.isEmpty) return const EmptyExpr();
        if (flat.length == 1) return flat.first;
        return OrExpr(flat);
    }
  }
}
