// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../editor/edit_operation.dart';
import '../editor/editor_controller.dart';
import '../editor/line_view.dart';
import '../editor/providers.dart';
import '../editor/source_editor_view.dart';
import '../vault/note_document.dart';
import '../vault/providers.dart';
import 'huge_note.dart';

/// Calculates the nearest-rank percentile [p] (0..100) of [values].
double percentile(List<double> values, double p) {
  if (values.isEmpty) return 0.0;
  final sorted = List<double>.from(values)..sort();
  final rank = (p / 100.0 * sorted.length).ceil();
  final index = (rank - 1).clamp(0, sorted.length - 1);
  return sorted[index];
}

class TypingBenchmarkScreen extends ConsumerStatefulWidget {
  const TypingBenchmarkScreen({super.key, this.autoRun = true});

  final bool autoRun;

  @override
  ConsumerState<TypingBenchmarkScreen> createState() =>
      _TypingBenchmarkScreenState();
}

class _TypingBenchmarkScreenState extends ConsumerState<TypingBenchmarkScreen> {
  final _benchPath = VaultPath('huge-5000-lines.md');
  late final MemoryVaultFileSystem _fs;
  late final NoteDocument _doc;
  bool _initialized = false;
  bool _running = false;
  String _status = 'Initializing 5,000-line note...';

  @override
  void initState() {
    super.initState();
    _initDoc();
  }

  Future<void> _initDoc() async {
    _fs = MemoryVaultFileSystem();
    final hugeText = generateHugeNote();
    await _fs.writeText(_benchPath, TextDocument(text: hugeText));

    _doc = NoteDocument(path: _benchPath, fs: _fs, clock: const SystemClock());
    await _doc.load();

    if (mounted) {
      setState(() {
        _initialized = true;
        _status = 'Ready to benchmark';
      });

      if (widget.autoRun) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _runBenchmark();
        });
      }
    }
  }

  Future<void> _runBenchmark() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = 'Waiting for editor attachment...';
    });

    // Wait until EditorController is attached
    EditorController? controller;
    for (var i = 0; i < 50; i++) {
      controller = ref.read(editorRegistryProvider).controllerFor(_benchPath);
      if (controller != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (controller == null) {
      setState(() {
        _running = false;
        _status = 'Error: EditorController did not attach';
      });
      return;
    }

    // Step a: place caret at start of line 2,500 (0-indexed line 2,499)
    final caretOffset = offsetOf(controller.lines, const LinePos(2499, 0));
    controller.select(caretOffset);
    controller.revealOffset(caretOffset, center: true);
    await SchedulerBinding.instance.endOfFrame;

    setState(() {
      _status = 'Running typing benchmark (500 keystrokes)...';
    });

    // Step b: register timings callback
    final typingTimings = <FrameTiming>[];
    void onTypingTimings(List<FrameTiming> timings) {
      typingTimings.addAll(timings);
    }

    SchedulerBinding.instance.addTimingsCallback(onTypingTimings);

    // Step c: insert 500 characters one character per frame
    const textPattern = 'The quick brown fox jumps over the lazy dog. ';
    var currentOffset = caretOffset;
    for (var i = 0; i < 500; i++) {
      final ch = textPattern[i % textPattern.length];
      controller.apply(
        EditOperation(currentOffset, currentOffset, ch),
        selectAfter: true,
      );
      currentOffset += ch.length;
      await SchedulerBinding.instance.endOfFrame;
    }

    // Step d: wait 1 s and remove callback
    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(onTypingTimings);

    final typingDurations = <double>[];
    for (final t in typingTimings) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      typingDurations.add(math.max(b, r));
    }

    final p50 = percentile(typingDurations, 50);
    final p90 = percentile(typingDurations, 90);
    final p95 = percentile(typingDurations, 95);
    final p99 = percentile(typingDurations, 99);
    final maxDuration = typingDurations.isEmpty
        ? 0.0
        : typingDurations.reduce(math.max);
    final over16 = typingDurations.where((d) => d > 16.0).length;

    // Step e: scroll benchmark (animate editor scroll from top to bottom in 5s)
    setState(() {
      _status = 'Running scroll benchmark (5s)...';
    });

    final scrollTimings = <FrameTiming>[];
    void onScrollTimings(List<FrameTiming> timings) {
      scrollTimings.addAll(timings);
    }

    SchedulerBinding.instance.addTimingsCallback(onScrollTimings);

    final scrollSw = Stopwatch()..start();
    final totalLines = controller.lines.lineCount;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    while (DateTime.now().millisecondsSinceEpoch - startMs < 5000) {
      final progress =
          (DateTime.now().millisecondsSinceEpoch - startMs) / 5000.0;
      final targetLine = (progress * (totalLines - 1))
          .clamp(0, totalLines - 1)
          .toInt();
      final targetOffset = offsetOf(controller.lines, LinePos(targetLine, 0));
      controller.revealOffset(targetOffset, center: true);
      await SchedulerBinding.instance.endOfFrame;
    }
    scrollSw.stop();
    SchedulerBinding.instance.removeTimingsCallback(onScrollTimings);

    final scrollDurations = <double>[];
    for (final t in scrollTimings) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      scrollDurations.add(math.max(b, r));
    }
    final scrollElapsedSec = scrollSw.elapsedMilliseconds / 1000.0;
    final scrollFps = scrollElapsedSec > 0
        ? scrollTimings.length / scrollElapsedSec
        : 0.0;
    final scrollP95 = percentile(scrollDurations, 95);

    // Parse benchmark on UI isolate
    final parseSw = Stopwatch()..start();
    final hugeText = generateHugeNote();
    MarkdownParser.parse(hugeText);
    parseSw.stop();
    final parseMs = parseSw.elapsedMilliseconds;

    // Highlight benchmark (40 consecutive dirty lines)
    if (!mounted) return;
    final theme = Theme.of(context);
    final highlighter = controller.highlighter;
    final hlSw = Stopwatch()..start();
    const testLinesCount = 40;
    for (var i = 0; i < testLinesCount; i++) {
      final lineIdx = 2480 + i;
      final lineStr = controller.lines.lineAt(lineIdx);
      highlighter.spanFor(lineIdx, lineStr, const TextStyle(), theme);
    }
    hlSw.stop();
    final hlMicrosPerLine = hlSw.elapsedMicroseconds / testLinesCount;

    // Print specified benchmark lines
    debugPrint(
      'PERF typing p50=${p50.toStringAsFixed(2)} p90=${p90.toStringAsFixed(2)} '
      'p95=${p95.toStringAsFixed(2)} p99=${p99.toStringAsFixed(2)} '
      'max=${maxDuration.toStringAsFixed(2)} over16=$over16 | '
      'scroll fps=${scrollFps.toStringAsFixed(1)} p95=${scrollP95.toStringAsFixed(2)}',
    );
    debugPrint('PERF parse-5000-lines $parseMs ms');
    debugPrint(
      'PERF highlight-visible-lines ${hlMicrosPerLine.toStringAsFixed(1)} µs per line',
    );

    if (mounted) {
      setState(() {
        _running = false;
        _status =
            'Done: typing p95=${p95.toStringAsFixed(2)} ms, scroll fps=${scrollFps.toStringAsFixed(1)}';
      });

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Typing & Scroll Benchmark Results'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Typing Frames: ${typingTimings.length}'),
                Text('Typing p50: ${p50.toStringAsFixed(2)} ms'),
                Text('Typing p90: ${p90.toStringAsFixed(2)} ms'),
                Text('Typing p95: ${p95.toStringAsFixed(2)} ms'),
                Text('Typing p99: ${p99.toStringAsFixed(2)} ms'),
                Text('Typing Max: ${maxDuration.toStringAsFixed(2)} ms'),
                Text('Frames > 16.0 ms: $over16'),
                const Divider(),
                Text('Scroll Frames: ${scrollTimings.length}'),
                Text('Scroll FPS: ${scrollFps.toStringAsFixed(1)}'),
                Text('Scroll p95: ${scrollP95.toStringAsFixed(2)} ms'),
                const Divider(),
                Text('Parse 5,000 lines: $parseMs ms'),
                Text(
                  'Highlight 40 lines: ${hlMicrosPerLine.toStringAsFixed(1)} µs/line',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Typing Benchmark')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Typing Benchmark (5,000 lines)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run Benchmark',
            onPressed: _running ? null : _runBenchmark,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                if (_running) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(_status)),
                ElevatedButton(
                  onPressed: _running ? null : _runBenchmark,
                  child: const Text('Run Benchmark'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ProviderScope(
              overrides: [
                vaultFsProvider.overrideWithValue(_fs),
                noteDocumentProvider(_benchPath).overrideWithValue(_doc),
              ],
              child: SourceEditorView(
                path: _benchPath,
                tabId: 'typing-bench-tab',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
