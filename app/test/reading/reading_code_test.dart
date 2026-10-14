// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/reading_code.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alias table maps aliases and returns null for unknown', () {
    final highlighter = CodeHighlighter.instance;
    expect(highlighter.languageId('js'), equals('javascript'));
    expect(highlighter.languageId('py'), equals('python'));
    expect(highlighter.languageId('ts'), equals('typescript'));
    expect(highlighter.languageId('rs'), equals('rust'));
    expect(highlighter.languageId('unknown'), isNull);
    expect(highlighter.languageId(null), isNull);
  });

  test('highlighted span count > 1 for dart code', () {
    final highlighter = CodeHighlighter.instance;
    final span = highlighter.highlightCode(
      code: 'void main() {\n  final x = 42;\n}',
      lang: 'dart',
      theme: ThemeData.light(),
    );

    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));
  });

  testWidgets('mermaid shows the codeRenderedLater chip', (tester) async {
    final node = MdCodeBlock(
      0,
      30,
      language: 'mermaid',
      code: 'graph TD\n  A-->B',
    );

    await tester.pumpWidget(testApp(Scaffold(body: CodeBlockView(node: node))));
    await tester.pumpAndSettle();

    expect(find.text('Rendered in a later version'), findsOneWidget);
  });

  test('code longer than 20,000 characters is not highlighted', () {
    final bigCode = 'final int a = 1;\n' * 1500; // > 24,000 characters
    expect(bigCode.length, greaterThan(20000));

    final highlighter = CodeHighlighter.instance;
    final span = highlighter.highlightCode(
      code: bigCode,
      lang: 'dart',
      theme: ThemeData.light(),
    );

    expect(span.children, isNull);
    expect(span.text, equals(bigCode));
  });

  testWidgets('copy button writes code without trailing newline', (
    tester,
  ) async {
    String? copiedText;

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText =
              (methodCall.arguments as Map<dynamic, dynamic>)['text']
                  as String?;
          return null;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final node = MdCodeBlock(
      0,
      20,
      language: 'dart',
      code: 'print("hello");\n',
    );

    await tester.pumpWidget(testApp(Scaffold(body: CodeBlockView(node: node))));
    await tester.pumpAndSettle();

    final copyButton = find.byType(IconButton);
    expect(copyButton, findsOneWidget);
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(copiedText, equals('print("hello");'));
  });
}
