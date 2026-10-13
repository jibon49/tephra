// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/editor_engine.dart';
import 'package:tephra/editor/highlight/source_highlighter.dart';
import 'package:tephra/editor/highlight/source_styles.dart';
import 'package:tephra/editor/line_view.dart';
import 'package:tephra/reading/parse_service.dart';

void main() {
  const parseService = ParseService();
  final theme = ThemeData.light();
  const baseStyle = TextStyle(fontSize: 16);

  group('SourceHighlighter', () {
    test('applyParse and spanFor for multi-line fenced block', () async {
      const markdown = '```dart\nvar x = 1;\n```';
      final parsed = await parseService.parse(markdown);
      final highlighter = SourceHighlighter();
      highlighter.applyParse(parsed, revision: 1);

      expect(highlighter.lineCount, equals(3));

      // Line 0: codeBlock and codeFence
      final runs0 = highlighter.runsForLine(0);
      expect(runs0.expand((r) => r.tokens), contains(SourceToken.codeBlock));
      expect(runs0.expand((r) => r.tokens), contains(SourceToken.codeFence));

      // Line 1: codeBlock
      final runs1 = highlighter.runsForLine(1);
      expect(runs1.expand((r) => r.tokens), contains(SourceToken.codeBlock));
      expect(
        runs1.expand((r) => r.tokens),
        isNot(contains(SourceToken.codeFence)),
      );

      // Line 2: codeBlock and codeFence
      final runs2 = highlighter.runsForLine(2);
      expect(runs2.expand((r) => r.tokens), contains(SourceToken.codeBlock));
      expect(runs2.expand((r) => r.tokens), contains(SourceToken.codeFence));

      // spanFor returns TextSpan with children
      final span0 = highlighter.spanFor(0, '```dart', baseStyle, theme);
      expect(span0.children, isNotEmpty);

      // lineKind is code
      expect(highlighter.lineKind(0), equals('code'));
      expect(highlighter.lineKind(1), equals('code'));
      expect(highlighter.lineKind(2), equals('code'));
    });

    test('bold word inside a heading merges heading1 and strong', () async {
      const markdown = '# Hello **world**';
      final parsed = await parseService.parse(markdown);
      final highlighter = SourceHighlighter();
      highlighter.applyParse(parsed, revision: 1);

      final runs = highlighter.runsForLine(0);
      // 'world' is located between offset 10 and 15
      final boldRun = runs.firstWhere((r) => r.start <= 10 && r.end >= 15);
      expect(boldRun.tokens, contains(SourceToken.heading1));
      expect(boldRun.tokens, contains(SourceToken.strong));

      final span = highlighter.spanFor(0, markdown, baseStyle, theme);
      expect(span.children, isNotEmpty);
    });

    test('stale revision is ignored', () async {
      final doc1 = await parseService.parse('# Version 1');
      final doc2 = await parseService.parse('## Version 2');

      final highlighter = SourceHighlighter();
      highlighter.applyParse(doc2, revision: 5);
      expect(highlighter.currentRevision, equals(5));
      expect(
        highlighter.runsForLine(0).expand((r) => r.tokens),
        contains(SourceToken.heading2),
      );

      // Stale revision 4 should be ignored
      highlighter.applyParse(doc1, revision: 4);
      expect(highlighter.currentRevision, equals(5));
      expect(
        highlighter.runsForLine(0).expand((r) => r.tokens),
        contains(SourceToken.heading2),
      );
    });

    test('onEdit inserting a line shifts later lines down and marks line dirty', () async {
      const markdown = 'line 0\nline 1\nline 2';
      final parsed = await parseService.parse(markdown);
      final highlighter = SourceHighlighter();
      highlighter.applyParse(parsed, revision: 1);
      expect(highlighter.lineCount, equals(3));

      // Insert a newline in line 1:
      // Change: start=10, deletedLength=0, insertedText='\n', isUndoRedo=false
      final newLines = ListLineView(['line 0', 'line', ' 1', 'line 2']);
      highlighter.onEdit(
        const EngineChange(
          start: 11,
          deletedLength: 0,
          insertedText: '\n',
          isUndoRedo: false,
        ),
        newLines,
      );

      // Line count should expand to 4
      expect(highlighter.lineCount, equals(4));
      // Touched lines are marked dirty
      expect(highlighter.isLineDirty(1), isTrue);
      expect(highlighter.isLineDirty(2), isTrue);

      // While dirty, spanFor falls back to QuickStyler
      final dirtySpan = highlighter.spanFor(
        1,
        '# quick heading',
        baseStyle,
        theme,
      );
      expect(dirtySpan.children, isNotEmpty);
    });

    test('overlays layer on top of base styles', () async {
      const markdown = 'Searching for match';
      final parsed = await parseService.parse(markdown);
      final highlighter = SourceHighlighter();
      highlighter.applyParse(parsed, revision: 1);

      highlighter.setOverlays([
        const OverlayRange(start: 14, end: 19, token: SourceToken.findMatch),
      ]);

      final span = highlighter.spanFor(0, markdown, baseStyle, theme);
      expect(span.children, isNotEmpty);
      // One of the children corresponds to 'match' with findMatch styling
      final matchSpan = span.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'match',
      );
      expect(matchSpan.style?.backgroundColor, isNotNull);
    });
  });
}
