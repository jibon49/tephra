// © 2026 Tephra. All rights reserved.

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

sealed class SearchExpr {
  const SearchExpr();
}

final class EmptyExpr extends SearchExpr {
  const EmptyExpr();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EmptyExpr;

  @override
  int get hashCode => 0;
}

final class AndExpr extends SearchExpr {
  const AndExpr(this.children);

  final List<SearchExpr> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AndExpr && _listEquals(children, other.children));

  @override
  int get hashCode => Object.hashAll(children);
}

final class OrExpr extends SearchExpr {
  const OrExpr(this.children);

  final List<SearchExpr> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrExpr && _listEquals(children, other.children));

  @override
  int get hashCode => Object.hashAll(children);
}

final class NotExpr extends SearchExpr {
  const NotExpr(this.child);

  final SearchExpr child;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NotExpr && child == other.child);

  @override
  int get hashCode => child.hashCode;
}

final class TermExpr extends SearchExpr {
  const TermExpr(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TermExpr && text == other.text);

  @override
  int get hashCode => text.hashCode;
}

final class PhraseExpr extends SearchExpr {
  const PhraseExpr(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PhraseExpr && text == other.text);

  @override
  int get hashCode => text.hashCode;
}

final class RegexExpr extends SearchExpr {
  const RegexExpr(this.pattern, this.flags);

  final String pattern;
  final String flags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexExpr && pattern == other.pattern && flags == other.flags);

  @override
  int get hashCode => Object.hash(pattern, flags);
}

enum SearchOperator {
  file,
  path,
  content,
  tag,
  line,
  block,
  section,
  task,
  taskTodo,
  taskDone,
  matchCase,
  ignoreCase;

  String get grammarName {
    switch (this) {
      case SearchOperator.file:
        return 'file';
      case SearchOperator.path:
        return 'path';
      case SearchOperator.content:
        return 'content';
      case SearchOperator.tag:
        return 'tag';
      case SearchOperator.line:
        return 'line';
      case SearchOperator.block:
        return 'block';
      case SearchOperator.section:
        return 'section';
      case SearchOperator.task:
        return 'task';
      case SearchOperator.taskTodo:
        return 'task-todo';
      case SearchOperator.taskDone:
        return 'task-done';
      case SearchOperator.matchCase:
        return 'match-case';
      case SearchOperator.ignoreCase:
        return 'ignore-case';
    }
  }

  static SearchOperator? tryFromGrammarName(String name) {
    switch (name.toLowerCase()) {
      case 'file':
        return SearchOperator.file;
      case 'path':
        return SearchOperator.path;
      case 'content':
        return SearchOperator.content;
      case 'tag':
        return SearchOperator.tag;
      case 'line':
        return SearchOperator.line;
      case 'block':
        return SearchOperator.block;
      case 'section':
        return SearchOperator.section;
      case 'task':
        return SearchOperator.task;
      case 'task-todo':
        return SearchOperator.taskTodo;
      case 'task-done':
        return SearchOperator.taskDone;
      case 'match-case':
        return SearchOperator.matchCase;
      case 'ignore-case':
        return SearchOperator.ignoreCase;
      default:
        return null;
    }
  }
}

final class OperatorExpr extends SearchExpr {
  const OperatorExpr(this.op, this.value);

  final SearchOperator op;
  final SearchExpr value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperatorExpr && op == other.op && value == other.value);

  @override
  int get hashCode => Object.hash(op, value);
}

sealed class PropertyValue {
  const PropertyValue();
}

final class PropertyExists extends PropertyValue {
  const PropertyExists();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PropertyExists;

  @override
  int get hashCode => 0;
}

final class PropertyIsEmpty extends PropertyValue {
  const PropertyIsEmpty();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PropertyIsEmpty;

  @override
  int get hashCode => 1;
}

final class PropertyMatches extends PropertyValue {
  const PropertyMatches(this.expr);

  final SearchExpr expr;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyMatches && expr == other.expr);

  @override
  int get hashCode => expr.hashCode;
}

final class PropertyExpr extends SearchExpr {
  const PropertyExpr(this.name, this.value);

  final String name;
  final PropertyValue value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyExpr && name == other.name && value == other.value);

  @override
  int get hashCode => Object.hash(name, value);
}
