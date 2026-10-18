// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Exception thrown when a search query fails to parse.
class SearchSyntaxException extends ParseException {
  const SearchSyntaxException(super.message, this.offset);

  /// 0-based character offset in the query where the error was encountered.
  final int offset;

  @override
  String toString() => 'SearchSyntaxException: $message at offset $offset';
}
