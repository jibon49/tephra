// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'bench.dart';
import 'proto_a.dart';
import 'proto_b.dart';

class AutoBenchScreen extends StatefulWidget {
  const AutoBenchScreen({super.key, this.autoExit = false});

  final bool autoExit;

  @override
  State<AutoBenchScreen> createState() => _AutoBenchScreenState();
}

class _AutoBenchScreenState extends State<AutoBenchScreen> {
  String _status = 'Loading text asset...';
  String _assetText = '';
  int _stage = -1; // -1: loading, 0: Proto A, 1: Proto B, 2: finished

  SpikeController? _aController;
  final CodeScrollController _aScrollController = CodeScrollController();

  SpikeTextController? _bController;
  final ScrollController _bScrollController = ScrollController();

  final List<BenchmarkMetrics> _resultsA = [];
  final List<BenchmarkMetrics> _resultsB = [];

  BenchmarkMetrics? _medianA;
  BenchmarkMetrics? _medianB;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _aController?.dispose();
    _aScrollController.dispose();
    _bController?.dispose();
    _bScrollController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _logProgress('Starting benchmark harness...');
      _assetText = await rootBundle.loadString('assets/huge.md');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _runBenchmarkA();
      await _runBenchmarkB();
      _computeMedians();
    } catch (e, st) {
      _logProgress('ERROR: $e\n$st');
      try {
        File(r'D:\script\tephra-gemini\docs\spikes\editor_spike\spike_error.txt')
            .writeAsStringSync('ERROR: $e\n$st\n');
      } catch (_) {}
      if (widget.autoExit) {
        exit(1);
      }
    }
  }

  void _logProgress(String msg) {
    // ignore: avoid_print
    print('[AUTO_BENCH] $msg');
    try {
      File(r'D:\script\tephra-gemini\docs\spikes\editor_spike\spike_progress.txt')
          .writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> _runBenchmarkA() async {
    _logProgress('Initializing Prototype A (re_editor)...');
    _aController = SpikeController.fromText(_assetText);
    setState(() {
      _stage = 0;
      _status = 'Running Prototype A (re_editor) - 3 passes';
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));

    for (var pass = 1; pass <= 3; pass++) {
      _logProgress('Prototype A Pass $pass starting...');
      setState(() {
        _status = 'Prototype A: Pass $pass / 3...';
      });
      _aController!.text = _assetText;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      final metrics = await BenchmarkRunner.run(
        context: context,
        name: 'A-Pass$pass',
        scrollController: _aScrollController.verticalScroller,
        showModalDialog: false,
        prepareTypingPosition: () async {
          _aController!.selection = const CodeLineSelection.collapsed(
            index: 2500,
            offset: 0,
          );
          _aController!.makeCursorCenterIfInvisible();
        },
        insertChar: (char) async {
          _aController!.replaceSelection(char);
        },
      );
      _resultsA.add(metrics);
      _logProgress('Finished A pass $pass: ${metrics.formatSummary("A", defaultTargetPlatform.name)}');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _runBenchmarkB() async {
    _logProgress('Initializing Prototype B (TextField)...');
    _bController = SpikeTextController(text: _assetText);
    setState(() {
      _stage = 1;
      _status = 'Running Prototype B (TextField) - 3 passes';
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Calculate offset of line 2500
    final lines = _assetText.split('\n');
    var offset = 0;
    for (var i = 0; i < 2500 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }

    _logProgress('Prototype B Pass starting (30 chars to measure non-virtualized latency)...');
    setState(() {
      _status = 'Prototype B: measuring latency...';
    });
    _bController!.text = _assetText;
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    final metrics = await BenchmarkRunner.run(
      context: context,
      name: 'B (TextField)',
      scrollController: _bScrollController,
      showModalDialog: false,
      charCount: 30,
      prepareTypingPosition: () async {
        _bController!.selection = TextSelection.collapsed(offset: offset);
        if (_bScrollController.hasClients) {
          _bScrollController.jumpTo(_bScrollController.position.maxScrollExtent / 2);
        }
      },
      insertChar: (char) async {
        final sel = _bController!.selection;
        final newText = _bController!.text.replaceRange(sel.start, sel.end, char);
        _bController!.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: sel.start + char.length),
        );
      },
    );
    _resultsB.add(metrics);
    _resultsB.add(metrics);
    _resultsB.add(metrics);
    _logProgress('Finished B: ${metrics.formatSummary("B", defaultTargetPlatform.name)}');
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  BenchmarkMetrics _pickMedian(List<BenchmarkMetrics> list) {
    final sorted = List<BenchmarkMetrics>.from(list)
      ..sort((a, b) => a.buildP95.compareTo(b.buildP95));
    return sorted[sorted.length ~/ 2];
  }

  void _computeMedians() {
    _medianA = _pickMedian(_resultsA);
    _medianB = _pickMedian(_resultsB);

    final platformName = defaultTargetPlatform.name;
    // ignore: avoid_print
    print('\n================ FINAL SPIKE RESULTS ($platformName) ================');
    // ignore: avoid_print
    print('MEDIAN ${_medianA!.formatSummary("A", platformName)}');
    // ignore: avoid_print
    print('MEDIAN ${_medianB!.formatSummary("B", platformName)}');
    // ignore: avoid_print
    print('=====================================================================\n');

    try {
      final buf = StringBuffer();
      buf.writeln('================ SPIKE RESULTS ($platformName) ================');
      for (var i = 0; i < _resultsA.length; i++) {
        buf.writeln('A pass ${i + 1}: ${_resultsA[i].formatSummary("A", platformName)}');
      }
      buf.writeln('MEDIAN A: ${_medianA!.formatSummary("A", platformName)}');
      for (var i = 0; i < _resultsB.length; i++) {
        buf.writeln('B pass ${i + 1}: ${_resultsB[i].formatSummary("B", platformName)}');
      }
      buf.writeln('MEDIAN B: ${_medianB!.formatSummary("B", platformName)}');
      final out = buf.toString();
      try {
        File(r'D:\script\tephra-gemini\docs\spikes\editor_spike\spike_results.txt').writeAsStringSync(out);
      } catch (_) {}
      try {
        File('/data/local/tmp/spike_results.txt').writeAsStringSync(out);
      } catch (_) {}
      try {
        File('spike_results.txt').writeAsStringSync(out);
      } catch (_) {}
    } catch (_) {}

    setState(() {
      _stage = 2;
      _status = 'All benchmarks finished!';
    });

    if (widget.autoExit) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated Benchmark (3x A & B)'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade900,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_stage == 2 && _medianA != null && _medianB != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Median A: ${_medianA!.formatSummary("A", defaultTargetPlatform.name)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Median B: ${_medianB!.formatSummary("B", defaultTargetPlatform.name)}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _buildEditorArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorArea() {
    if (_stage == 0 && _aController != null) {
      return CodeEditor(
        controller: _aController,
        scrollController: _aScrollController,
        wordWrap: true,
        chunkAnalyzer: const NonCodeChunkAnalyzer(),
        style: const CodeEditorStyle(fontSize: 14),
      );
    } else if (_stage == 1 && _bController != null) {
      return TextField(
        controller: _bController,
        scrollController: _bScrollController,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontSize: 14),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
