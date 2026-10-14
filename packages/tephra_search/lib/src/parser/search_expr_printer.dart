// © 2026 Tephra. All rights reserved.

import 'search_expr.dart';

/// Returns the canonical string representation of [e] used by tests and logs.
String printExpr(SearchExpr e) {
  switch (e) {
    case EmptyExpr():
      return 'empty';
    case AndExpr():
      return 'and(${e.children.map(printExpr).join(', ')})';
    case OrExpr():
      return 'or(${e.children.map(printExpr).join(', ')})';
    case NotExpr():
      return 'not(${printExpr(e.child)})';
    case TermExpr():
      return 'term(${e.text})';
    case PhraseExpr():
      return 'phrase(${e.text})';
    case RegexExpr():
      return 'regex(${e.pattern}/${e.flags})';
    case OperatorExpr():
      return '${e.op.grammarName}(${printExpr(e.value)})';
    case PropertyExpr():
      switch (e.value) {
        case PropertyExists():
          return 'prop(${e.name})';
        case PropertyIsEmpty():
          return 'prop(${e.name}:empty)';
        case PropertyMatches(:final expr):
          return 'prop(${e.name}:${printExpr(expr)})';
      }
  }
}
