// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'bench.dart';

class SpikeController extends CodeLineEditingControllerDelegate {
  SpikeController.fromText(String text)
      : super(
          delegate: CodeLineEditingController(
            codeLines: CodeLines.fromText(text),
          ),
        );

  bool testWidgetSpan = false;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final line = codeLines[index].text;
    final isCursorLine = selection.extentIndex == index;

    if (testWidgetSpan && index == 10) {
      try {
        return TextSpan(
          style: style,
          children: [
            const WidgetSpan(
              child: SizedBox(
                width: 48,
                height: 32,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
            WidgetSpan(
              child: Checkbox(value: true, onChanged: (_) {}),
            ),
            TextSpan(text: ' $line'),
          ],
        );
      } catch (e) {
        // re_editor does not support WidgetSpan
        return TextSpan(text: '[WidgetSpan error: $e] $line', style: style);
      }
    }

    return _styleMarkdownLine(line, isCursorLine, style);
  }
}

final _headingRegex = RegExp(r'^(#{1,6})\s+(.*)$');
final _inlineRegex = RegExp(
  r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)|(\[\[(.+?)\]\])|(#[a-zA-Z0-9_\-]+)',
);

TextSpan _styleMarkdownLine(String line, bool isCursorLine, TextStyle baseStyle) {
  final hiddenStyle = baseStyle.copyWith(
    fontSize: 0.01,
    color: Colors.transparent,
  );
  final markerStyle = baseStyle.copyWith(
    color: Colors.grey,
    fontWeight: FontWeight.normal,
  );

  // Check for heading: ^(#{1,6})\s+(.*)$
  final headingMatch = _headingRegex.firstMatch(line);
  if (headingMatch != null) {
    final hashes = headingMatch.group(1)!;
    final content = headingMatch.group(2)!;
    final level = hashes.length;
    final headingSize = (baseStyle.fontSize ?? 14.0) + (7 - level) * 2.0;
    final hStyle = baseStyle.copyWith(
      fontSize: headingSize,
      fontWeight: FontWeight.bold,
    );

    return TextSpan(
      children: [
        TextSpan(
          text: '$hashes ',
          style: isCursorLine ? markerStyle : hiddenStyle,
        ),
        TextSpan(text: content, style: hStyle),
      ],
    );
  }

  // Segment styling with inline spans
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in _inlineRegex.allMatches(line)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: line.substring(cursor, match.start), style: baseStyle));
    }

    final fullMatch = match.group(0)!;
    if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
      final inner = match.group(2)!;
      spans.add(TextSpan(text: '**', style: isCursorLine ? markerStyle : hiddenStyle));
      spans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: '**', style: isCursorLine ? markerStyle : hiddenStyle));
    } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
      final inner = match.group(4)!;
      spans.add(TextSpan(text: '*', style: isCursorLine ? markerStyle : hiddenStyle));
      spans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      spans.add(TextSpan(text: '*', style: isCursorLine ? markerStyle : hiddenStyle));
    } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
      final inner = match.group(6)!;
      spans.add(TextSpan(text: '`', style: isCursorLine ? markerStyle : hiddenStyle));
      spans.add(TextSpan(text: inner, style: baseStyle.copyWith(backgroundColor: Colors.grey.shade200, fontFamily: 'monospace')));
      spans.add(TextSpan(text: '`', style: isCursorLine ? markerStyle : hiddenStyle));
    } else if (fullMatch.startsWith('[[') && fullMatch.endsWith(']]')) {
      final inner = match.group(8)!;
      spans.add(TextSpan(text: '[[', style: isCursorLine ? markerStyle : hiddenStyle));
      spans.add(TextSpan(text: inner, style: baseStyle.copyWith(color: Colors.blue, decoration: TextDecoration.underline)));
      spans.add(TextSpan(text: ']]', style: isCursorLine ? markerStyle : hiddenStyle));
    } else if (fullMatch.startsWith('#')) {
      spans.add(TextSpan(text: fullMatch, style: baseStyle.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.w600)));
    }
    cursor = match.end;
  }

  if (cursor < line.length) {
    spans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
  }

  return TextSpan(children: spans.isEmpty ? [TextSpan(text: line, style: baseStyle)] : spans);
}

class ProtoAScreen extends StatefulWidget {
  const ProtoAScreen({super.key});

  @override
  State<ProtoAScreen> createState() => _ProtoAScreenState();
}

class _ProtoAScreenState extends State<ProtoAScreen> {
  SpikeController? _controller;
  final CodeScrollController _scrollController = CodeScrollController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    final text = await rootBundle.loadString('assets/huge.md');
    setState(() {
      _controller = SpikeController.fromText(text);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<BenchmarkMetrics?> runBenchmark({bool showModalDialog = true}) async {
    if (_controller == null) return null;
    return BenchmarkRunner.run(
      context: context,
      name: 'A (re_editor)',
      scrollController: _scrollController.verticalScroller,
      showModalDialog: showModalDialog,
      prepareTypingPosition: () async {
        _controller!.selection = const CodeLineSelection.collapsed(
          index: 2500,
          offset: 0,
        );
        _controller!.makeCursorCenterIfInvisible();
      },
      insertChar: (char) async {
        _controller!.replaceSelection(char);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prototype A: re_editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets),
            tooltip: 'Toggle WidgetSpan in line 10',
            onPressed: () {
              setState(() {
                _controller!.testWidgetSpan = !_controller!.testWidgetSpan;
                _controller!.notifyListeners();
              });
            },
          ),
          FilledButton.icon(
            onPressed: () => runBenchmark(),
            icon: const Icon(Icons.speed),
            label: const Text('Run benchmark'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CodeEditor(
        controller: _controller,
        scrollController: _scrollController,
        wordWrap: true,
        chunkAnalyzer: const NonCodeChunkAnalyzer(),
        style: const CodeEditorStyle(
          fontSize: 14,
        ),
      ),
    );
  }
}
