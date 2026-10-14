// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/search/copy_results.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

void main() {
  test('two results (one with 12 matches, one file-name match only) -> exact expected string (10 sub-lines for the first, none for the second)', () {
    final matches12 = List.generate(
      12,
      (i) => SearchMatch(
        line: i,
        start: i * 20,
        end: i * 20 + 5,
        snippet: 'Line match $i',
        snippetStart: 0,
        snippetEnd: 4,
        inFileName: false,
      ),
    );

    final result1 = SearchResult(VaultPath('Alpha.md'), matches12);

    final result2 = SearchResult(VaultPath('Beta.md'), const [
      SearchMatch(
        line: -1,
        start: 0,
        end: 0,
        snippet: 'Beta.md',
        snippetStart: 0,
        snippetEnd: 4,
        inFileName: true,
      ),
    ]);

    const fmtSettings = LinkFormatSettings(
      format: NewLinkFormat.shortest,
      useMarkdownLinks: false,
    );
    final fmt = LinkFormatter(NameTable(), fmtSettings);
    final from = VaultPath('Root.md');

    final markdown = formatResultsAsMarkdown([result1, result2], fmt, from);

    final expected = StringBuffer()
      ..writeln('- [[Alpha]]')
      ..writeln('\t- Line match 0')
      ..writeln('\t- Line match 1')
      ..writeln('\t- Line match 2')
      ..writeln('\t- Line match 3')
      ..writeln('\t- Line match 4')
      ..writeln('\t- Line match 5')
      ..writeln('\t- Line match 6')
      ..writeln('\t- Line match 7')
      ..writeln('\t- Line match 8')
      ..writeln('\t- Line match 9')
      ..writeln('- [[Beta]]');

    expect(markdown, equals(expected.toString()));
  });
}
