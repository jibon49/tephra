// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';

/// Options configuring search queries in find & replace.
@immutable
final class FindOptions {
  const FindOptions({
    this.query = '',
    this.matchCase = false,
    this.wholeWord = false,
    this.regex = false,
  });

  final String query;
  final bool matchCase;
  final bool wholeWord;
  final bool regex;

  FindOptions copyWith({
    String? query,
    bool? matchCase,
    bool? wholeWord,
    bool? regex,
  }) => FindOptions(
    query: query ?? this.query,
    matchCase: matchCase ?? this.matchCase,
    wholeWord: wholeWord ?? this.wholeWord,
    regex: regex ?? this.regex,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FindOptions &&
          query == other.query &&
          matchCase == other.matchCase &&
          wholeWord == other.wholeWord &&
          regex == other.regex;

  @override
  int get hashCode => Object.hash(query, matchCase, wholeWord, regex);

  @override
  String toString() =>
      'FindOptions(query: "$query", matchCase: $matchCase, wholeWord: $wholeWord, regex: $regex)';
}
