// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart' hide TextRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/live_preview/block_decorator.dart';
import 'package:tephra/editor/live_preview/live_preview_engine.dart';
import 'package:tephra/editor/live_preview/lp_options.dart';
import 'package:tephra/editor/live_preview/reveal.dart';
import 'package:tephra/editor/live_preview/span_builder.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

String visibleText(TextSpan span) {
  final buf = StringBuffer();
  void walk(InlineSpan s) {
    if (s is WidgetSpan) {
      buf.write('\uFFFC');
    } else if (s is TextSpan) {
      final isHidden =
          s.style?.fontSize == 0.01 || s.style?.color == Colors.transparent;
      if (!isHidden && s.text != null) {
        buf.write(s.text);
      }
      if (s.children != null) {
        for (final c in s.children!) {
          walk(c);
        }
      }
    }
  }

  walk(span);
  return buf.toString();
}

void main() {
  const base = TextStyle(fontSize: 16.0, color: Colors.black);

  test('emphasis bold reveal rules', () {
    const text = '**bold** text';
    final parsed = MarkdownParser.parse(text);
    final decos = decorateChunk(text, parsed, 0, const LpOptions());

    // Caret at 13 (outside)
    var span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 13, end: 13),
      base: base,
    );
    expect(visibleText(span), equals('bold text'));

    // Caret at 3 (inside bold)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 3, end: 3),
      base: base,
    );
    expect(visibleText(span), equals('**bold** text'));

    // Caret at 8 (touching the end)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 8, end: 8),
      base: base,
    );
    expect(visibleText(span), equals('**bold** text'));

    // Caret at 9 (outside, space after)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 9, end: 9),
      base: base,
    );
    expect(visibleText(span), equals('bold text'));

    // Selection spanning (0, 13)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 0, end: 13),
      base: base,
    );
    expect(visibleText(span), equals('**bold** text'));
  });

  test('heading scale and reveal', () {
    const text = '# Title';
    final parsed = MarkdownParser.parse(text);
    final decos = decorateChunk(text, parsed, 0, const LpOptions());

    // Caret on another line (e.g. 100)
    var span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 100, end: 100),
      base: base,
    );
    expect(visibleText(span), equals('Title'));

    // Heading scale 2.0 applied
    final titleSpan = span.children!.firstWhere(
      (s) => s is TextSpan && s.text == 'Title',
    ) as TextSpan;
    expect(titleSpan.style!.fontSize, equals(32.0));

    // Caret on the line (e.g. 2)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 2, end: 2),
      base: base,
    );
    expect(visibleText(span), equals('# Title'));
  });

  test('wikilink alias and external link', () {
    const text = '[[Note|alias]] x';
    final parsed = MarkdownParser.parse(text);
    final decos = decorateChunk(text, parsed, 0, const LpOptions());

    // Caret at 15
    var span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 15, end: 15),
      base: base,
    );
    expect(visibleText(span), equals('alias x'));

    // Caret at 5
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 5, end: 5),
      base: base,
    );
    expect(visibleText(span), equals('[[Note|alias]] x'));

    // Markdown link
    const linkText = '[t](http://a.b) z';
    final linkParsed = MarkdownParser.parse(linkText);
    final linkDecos = decorateChunk(linkText, linkParsed, 0, const LpOptions());
    final linkSpan = buildLpLine(
      lineText: linkText,
      lineStart: 0,
      lineEnd: linkText.length,
      decorations: linkDecos,
      active: TextRange(start: linkText.length, end: linkText.length),
      base: base,
    );
    expect(visibleText(linkSpan), equals('t z'));
  });

  test('list item bullet replacement', () {
    const text = '- item';
    final parsed = MarkdownParser.parse(text);
    final decos = decorateChunk(text, parsed, 0, const LpOptions());

    final span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 2, end: 2),
      base: base,
    );
    expect(visibleText(span), equals('• item'));
  });

  test('task item with W1 mode', () {
    const text = '- [ ] todo';
    final parsed = MarkdownParser.parse(text);
    final decos = decorateChunk(text, parsed, 0, const LpOptions());

    // Caret elsewhere (e.g. 8)
    var span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 8, end: 8),
      base: base,
      useWidgets: true,
    );
    expect(visibleText(span), equals(' \uFFFC todo'));

    // Caret inside box (e.g. 3)
    span = buildLpLine(
      lineText: text,
      lineStart: 0,
      lineEnd: text.length,
      decorations: decos,
      active: const TextRange(start: 3, end: 3),
      base: base,
      useWidgets: true,
    );
    expect(visibleText(span), equals('- [ ] todo'));
  });

  test('callout reveal behavior', () {
    const fullText = '> [!note] Title\n> body';
    final parsed = MarkdownParser.parse(fullText);
    final decos = decorateChunk(fullText, parsed, 0, const LpOptions());

    const line0 = '> [!note] Title';
    const line1 = '> body';

    // Caret outside callout (e.g. 100)
    var span0 = buildLpLine(
      lineText: line0,
      lineStart: 0,
      lineEnd: line0.length,
      decorations: decos,
      active: const TextRange(start: 100, end: 100),
      base: base,
      useWidgets: true,
    );
    var span1 = buildLpLine(
      lineText: line1,
      lineStart: line0.length + 1,
      lineEnd: fullText.length,
      decorations: decos,
      active: const TextRange(start: 100, end: 100),
      base: base,
      useWidgets: true,
    );
    expect(visibleText(span0), equals('\uFFFC'));
    expect(visibleText(span1), equals('body'));

    // Caret anywhere inside (e.g. 2 in line 0)
    span0 = buildLpLine(
      lineText: line0,
      lineStart: 0,
      lineEnd: line0.length,
      decorations: decos,
      active: const TextRange(start: 2, end: 2),
      base: base,
      useWidgets: true,
    );
    span1 = buildLpLine(
      lineText: line1,
      lineStart: line0.length + 1,
      lineEnd: fullText.length,
      decorations: decos,
      active: const TextRange(start: 2, end: 2),
      base: base,
      useWidgets: true,
    );
    expect(visibleText(span0), equals('> [!note] Title'));
    expect(visibleText(span1), equals('> body'));
  });

  test('table caret reveal', () {
    const fullText = '| A | B |\n| --- | --- |\n| 1 | 2 |';
    final parsed = MarkdownParser.parse(fullText);
    final decos = decorateChunk(fullText, parsed, 0, const LpOptions());

    final lines = fullText.split('\n');
    var offset = 0;
    // Caret in row 2 (offset inside '| 1 | 2 |')
    final active = TextRange(
      start: fullText.length - 3,
      end: fullText.length - 3,
    );

    for (final line in lines) {
      final span = buildLpLine(
        lineText: line,
        lineStart: offset,
        lineEnd: offset + line.length,
        decorations: decos,
        active: active,
        base: base,
        useWidgets: true,
      );
      // Since active touches table reveal, all rows are source
      expect(visibleText(span), equals(line));
      offset += line.length + 1;
    }
  });

  test('invariant test across all syntax notes', () {
    final syntaxDir = Directory('test_vaults/syntax').existsSync()
        ? Directory('test_vaults/syntax')
        : Directory('../test_vaults/syntax');
    final files = syntaxDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    expect(files, isNotEmpty);

    for (final file in files) {
      final text = file.readAsStringSync().replaceAll('\r\n', '\n');
      final engine = LivePreviewEngine();
      engine.setText(text);

      final lines = text.split('\n');
      final testActives = [
        const TextRange(start: 0, end: 0),
        TextRange(start: text.length ~/ 2, end: text.length ~/ 2),
        TextRange(start: text.length, end: text.length),
      ];

      for (final useWidgets in [true, false]) {
        for (final active in testActives) {
          var lineStart = 0;
          for (var i = 0; i < lines.length; i++) {
            final lineText = lines[i];
            final lineEnd = lineStart + lineText.length;
            final decos = engine.decorationsFor(lineStart, lineEnd + 1);

            final span = buildLpLine(
              lineText: lineText,
              lineStart: lineStart,
              lineEnd: lineEnd,
              decorations: decos,
              active: active,
              base: base,
              useWidgets: useWidgets,
            );

            final plainLen = span.toPlainText(includePlaceholders: true).length;
            expect(
              plainLen,
              equals(lineEnd - lineStart),
              reason:
                  'Line $i in ${file.path} failed length invariant with useWidgets=$useWidgets, active=$active',
            );

            lineStart = lineEnd + 1;
          }
        }
      }
    }
  });
}
