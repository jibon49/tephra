// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

/// Parses a note; notes longer than [isolateThreshold] UTF-16 units are parsed in a short-lived isolate (conventions §5.6).
final class ParseService {
  const ParseService({this.isolateThreshold = 50000});

  final int isolateThreshold;

  /// Parses [text] into a [ParsedNote].
  Future<ParsedNote> parse(String text) {
    if (kIsWeb || text.length <= isolateThreshold) {
      return Future.value(MarkdownParser.parse(text));
    }
    return Isolate.run(() => MarkdownParser.parse(text));
  }
}
