// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bench.dart';

final _headingRegex = RegExp(r'^(#{1,6})\s+(.*)$');
final _inlineRegex = RegExp(
  r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)|(\[\[(.+?)\]\])|(#[a-zA-Z0-9_\-]+)',
);

class SpikeTextController extends TextEditingController {
  SpikeTextController({super.text});

  bool testWidgetSpan = false;

  void requestRefresh() {
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle(fontSize: 14, color: Colors.black87);
    final hiddenStyle = baseStyle.copyWith(fontSize: 0.01, color: Colors.transparent);
    final markerStyle = baseStyle.copyWith(color: Colors.grey, fontWeight: FontWeight.normal);

    final lines = text.split('\n');
    final cursorOffset = selection.extentOffset;

    // Determine which line contains the cursor
    var charCount = 0;
    var cursorLine = -1;
    for (var i = 0; i < lines.length; i++) {
      final lineLen = lines[i].length + 1; // + \n
      if (cursorOffset >= charCount && cursorOffset < charCount + lineLen) {
        cursorLine = i;
        break;
      }
      charCount += lineLen;
    }

    final lineSpans = <InlineSpan>[];
    for (var idx = 0; idx < lines.length; idx++) {
      final line = lines[idx];
      final isCursorLine = idx == cursorLine;

      if (testWidgetSpan && idx == 10) {
        try {
          lineSpans.add(
            const WidgetSpan(
              child: SizedBox(
                width: 48,
                height: 32,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          );
          lineSpans.add(
            WidgetSpan(child: Checkbox(value: true, onChanged: (_) {})),
          );
          lineSpans.add(TextSpan(text: ' $line\n', style: baseStyle));
          continue;
        } catch (e) {
          lineSpans.add(TextSpan(text: '[WidgetSpan error: $e] $line\n', style: baseStyle));
          continue;
        }
      }

      // Check heading: ^(#{1,6})\s+(.*)$
      final headingMatch = _headingRegex.firstMatch(line);
      if (headingMatch != null) {
        final hashes = headingMatch.group(1)!;
        final content = headingMatch.group(2)!;
        final level = hashes.length;
        final headingSize = (baseStyle.fontSize ?? 14.0) + (7 - level) * 2.0;
        final hStyle = baseStyle.copyWith(fontSize: headingSize, fontWeight: FontWeight.bold);

        lineSpans.add(TextSpan(text: '$hashes ', style: isCursorLine ? markerStyle : hiddenStyle));
        lineSpans.add(TextSpan(text: '$content\n', style: hStyle));
        continue;
      }

      // Inline regex matching
      var cursor = 0;
      for (final match in _inlineRegex.allMatches(line)) {
        if (match.start > cursor) {
          lineSpans.add(TextSpan(text: line.substring(cursor, match.start), style: baseStyle));
        }
        final fullMatch = match.group(0)!;
        if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
          final inner = match.group(2)!;
          lineSpans.add(TextSpan(text: '**', style: isCursorLine ? markerStyle : hiddenStyle));
          lineSpans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
          lineSpans.add(TextSpan(text: '**', style: isCursorLine ? markerStyle : hiddenStyle));
        } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
          final inner = match.group(4)!;
          lineSpans.add(TextSpan(text: '*', style: isCursorLine ? markerStyle : hiddenStyle));
          lineSpans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
          lineSpans.add(TextSpan(text: '*', style: isCursorLine ? markerStyle : hiddenStyle));
        } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
          final inner = match.group(6)!;
          lineSpans.add(TextSpan(text: '`', style: isCursorLine ? markerStyle : hiddenStyle));
          lineSpans.add(TextSpan(text: inner, style: baseStyle.copyWith(backgroundColor: Colors.grey.shade200, fontFamily: 'monospace')));
          lineSpans.add(TextSpan(text: '`', style: isCursorLine ? markerStyle : hiddenStyle));
        } else if (fullMatch.startsWith('[[') && fullMatch.endsWith(']]')) {
          final inner = match.group(8)!;
          lineSpans.add(TextSpan(text: '[[', style: isCursorLine ? markerStyle : hiddenStyle));
          lineSpans.add(TextSpan(text: inner, style: baseStyle.copyWith(color: Colors.blue, decoration: TextDecoration.underline)));
          lineSpans.add(TextSpan(text: ']]', style: isCursorLine ? markerStyle : hiddenStyle));
        } else if (fullMatch.startsWith('#')) {
          lineSpans.add(TextSpan(text: fullMatch, style: baseStyle.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.w600)));
        }
        cursor = match.end;
      }

      if (cursor < line.length) {
        lineSpans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
      }
      lineSpans.add(const TextSpan(text: '\n'));
    }

    return TextSpan(children: lineSpans);
  }
}

class ProtoBScreen extends StatefulWidget {
  const ProtoBScreen({super.key});

  @override
  State<ProtoBScreen> createState() => _ProtoBScreenState();
}

class _ProtoBScreenState extends State<ProtoBScreen> {
  SpikeTextController? _controller;
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    final text = await rootBundle.loadString('assets/huge.md');
    setState(() {
      _controller = SpikeTextController(text: text);
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

    // Find character offset of line 2500
    final lines = _controller!.text.split('\n');
    var offset = 0;
    for (var i = 0; i < 2500 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }

    return BenchmarkRunner.run(
      context: context,
      name: 'B (TextField)',
      scrollController: _scrollController,
      showModalDialog: showModalDialog,
      prepareTypingPosition: () async {
        _controller!.selection = TextSelection.collapsed(offset: offset);
        // Scroll roughly to middle
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent / 2);
        }
      },
      insertChar: (char) async {
        final sel = _controller!.selection;
        final newText = _controller!.text.replaceRange(sel.start, sel.end, char);
        _controller!.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: sel.start + char.length),
        );
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
        title: const Text('Prototype B: TextField'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets),
            tooltip: 'Toggle WidgetSpan in line 10',
            onPressed: () {
              setState(() {
                _controller!.testWidgetSpan = !_controller!.testWidgetSpan;
                _controller!.requestRefresh();
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
      body: TextField(
        controller: _controller,
        scrollController: _scrollController,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
