// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_search/tephra_search.dart';

import '../../commands/quick_switcher_items.dart';
import '../../core/providers.dart';
import '../../editor/autocomplete/autocomplete_ranker.dart';
import '../../editor/edit_operation.dart';
import '../../editor/editor_controller.dart';
import '../../editor/line_view.dart';
import '../../editor/live_preview/editing_mode.dart';
import '../../editor/providers.dart';
import '../../vault/providers.dart';
import '../../workspace/providers.dart';
import '../../workspace/workspace_models.dart';
import 'perf_probe.dart';
import 'perf_stats.dart';

/// S2: First full index of the vault, UI usable.
/// Records: `index.full`, `ui.index.frame.p95`, `ui.index.frame.max`.
Future<void> runScenarioS2(
  WidgetRef ref, {
  ScrollController? scrollController,
}) async {
  final index = await ref.read(noteIndexProvider.future);
  final timings = <FrameTiming>[];
  void onTiming(List<FrameTiming> list) => timings.addAll(list);
  SchedulerBinding.instance.addTimingsCallback(onTiming);

  Future<void>? scrollFuture;
  if (scrollController != null && scrollController.hasClients) {
    scrollFuture = scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(seconds: 5),
      curve: Curves.linear,
    );
  }

  final sw = Stopwatch()..start();
  try {
    await index.rebuild();
    if (scrollFuture != null) {
      await scrollFuture.timeout(const Duration(seconds: 6), onTimeout: () {});
    }
  } finally {
    sw.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    SchedulerBinding.instance.removeTimingsCallback(onTiming);
  }

  PerfProbe.record('index.full', sw.elapsedMicroseconds / 1000.0, 'ms');
  final stats = frameStats(timings);
  PerfProbe.record('ui.index.frame.p95', stats.p95, 'ms');
  PerfProbe.record('ui.index.frame.max', stats.max, 'ms');
}

/// S3: Typing latency, 5,000-line note in Source mode and Live Preview mode.
/// Records: `typing.source.p95`, `typing.lp.p95`, `lp.applyEdit.median`.
Future<void> runScenarioS3(WidgetRef ref) async {
  final hugePath = VaultPath('Huge-5000-lines.md');
  final workspace = ref.read(workspaceProvider.notifier);
  final registry = ref.read(editorRegistryProvider);

  for (final mode in [EditingMode.source, EditingMode.livePreview]) {
    workspace.openPath(hugePath, editingMode: mode);
    final activeTab = ref.read(workspaceProvider).focusedTab;
    if (activeTab != null && activeTab.mode != ViewMode.source) {
      workspace.setMode(activeTab.id, ViewMode.source);
    }

    EditorController? controller;
    for (var i = 0; i < 50; i++) {
      controller = registry.controllerFor(hugePath);
      if (controller != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (controller == null) continue;

    // Line 2500 (0-indexed line 2499)
    final lineCount = controller.lines.lineCount;
    final targetLine = lineCount > 2499 ? 2499 : lineCount ~/ 2;
    final caretOffset = offsetOf(controller.lines, LinePos(targetLine, 0));
    controller.select(caretOffset);
    controller.revealOffset(caretOffset, center: true);
    await SchedulerBinding.instance.endOfFrame;

    final timings = <FrameTiming>[];
    void onTiming(List<FrameTiming> list) => timings.addAll(list);
    SchedulerBinding.instance.addTimingsCallback(onTiming);

    const pattern = 'The quick brown fox jumps over the lazy dog. ';
    var currentOffset = caretOffset;
    final applyDurations = <double>[];

    for (var i = 0; i < 500; i++) {
      final ch = pattern[i % pattern.length];
      final sw = Stopwatch()..start();
      controller.applyEdits([EditOperation(currentOffset, currentOffset, ch)]);
      sw.stop();
      applyDurations.add(sw.elapsedMicroseconds / 1000.0);
      currentOffset += ch.length;
      await SchedulerBinding.instance.endOfFrame;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    SchedulerBinding.instance.removeTimingsCallback(onTiming);

    final stats = frameStats(timings);
    if (mode == EditingMode.source) {
      PerfProbe.record('typing.source.p95', stats.p95, 'ms');
    } else {
      PerfProbe.record('typing.lp.p95', stats.p95, 'ms');
      if (applyDurations.isNotEmpty) {
        final med = percentile(applyDurations, 50);
        PerfProbe.record('lp.applyEdit.median', med, 'ms');
      }
    }
  }
}

/// S4: Plain-text search, 10k notes.
/// Records: `search.first.p95`, `search.total.rare.p95`, `search.total.common.p95`.
Future<void> runScenarioS4(WidgetRef ref) async {
  final session = ref.read(vaultSessionProvider);
  final index = await ref.read(noteIndexProvider.future);
  if (session == null) return;

  final engine = SearchEngine(index, session.fs);
  const commonQueries = ['report', 'meeting notes', '"project alpha"'];
  const rareQueries = ['quokka', '"quarterly report"'];
  final allQueries = [...commonQueries, ...rareQueries];

  final firstTimesAll = <double>[];
  final rareTotals = <double>[];
  final commonTotals = <double>[];

  for (final q in allQueries) {
    final expr = SearchParser.parse(q);
    final isRare = rareQueries.contains(q);

    // 3 warm-up runs
    for (var i = 0; i < 3; i++) {
      final stream = engine.run(expr);
      await stream.drain<void>();
    }

    // 20 measured runs
    for (var i = 0; i < 20; i++) {
      final sw = Stopwatch()..start();
      double? firstMs;
      var count = 0;

      final completer = Completer<void>();
      final stream = engine.run(expr);
      final sub = stream.listen(
        (res) {
          count++;
          if (count == 20 && firstMs == null) {
            firstMs = sw.elapsedMicroseconds / 1000.0;
          }
        },
        onDone: () {
          sw.stop();
          firstMs ??= sw.elapsedMicroseconds / 1000.0;
          completer.complete();
        },
        onError: (Object err) {
          sw.stop();
          completer.complete();
        },
      );

      await completer.future;
      await sub.cancel();

      final totalMs = sw.elapsedMicroseconds / 1000.0;
      firstTimesAll.add(firstMs!);
      if (isRare) {
        rareTotals.add(totalMs);
      } else {
        commonTotals.add(totalMs);
      }
    }
  }

  if (firstTimesAll.isNotEmpty) {
    PerfProbe.record('search.first.p95', percentile(firstTimesAll, 95), 'ms');
  }
  if (rareTotals.isNotEmpty) {
    PerfProbe.record('search.total.rare.p95', percentile(rareTotals, 95), 'ms');
  }
  if (commonTotals.isNotEmpty) {
    PerfProbe.record(
      'search.total.common.p95',
      percentile(commonTotals, 95),
      'ms',
    );
  }
}

/// S5: Quick switcher and autocomplete ranking performance.
/// Records: `switcher.p95`, `autocomplete.p95`.
Future<void> runScenarioS5(WidgetRef ref) async {
  final allItems = await ref.read(switcherItemsProvider.future);
  final titles = allItems
      .map((i) => i.primary)
      .where((t) => t.isNotEmpty)
      .toList();

  final rng = math.Random(42);
  final queries = <String>[];
  for (var i = 0; i < 50; i++) {
    if (titles.isEmpty) {
      queries.add('a');
      continue;
    }
    final title = titles[rng.nextInt(titles.length)];
    final len = 1 + rng.nextInt(math.min(6, math.max(1, title.length)));
    final start = rng.nextInt(math.max(1, title.length - len + 1));
    queries.add(title.substring(start, start + len));
  }

  final switcherTimes = <double>[];
  for (final q in queries) {
    final sw = Stopwatch()..start();
    final scored = <(SwitcherItem, int)>[];
    for (final item in allItems) {
      final s = FuzzyScorer.score(q, item.primary);
      if (s != null) scored.add((item, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    sw.stop();
    switcherTimes.add(sw.elapsedMicroseconds / 1000.0);
  }

  if (switcherTimes.isNotEmpty) {
    PerfProbe.record('switcher.p95', percentile(switcherTimes, 95), 'ms');
  }

  // Autocomplete ranking on notes
  final autocompleteTimes = <double>[];
  for (final q in queries.map((q) => q[0])) {
    final sw = Stopwatch()..start();
    AutocompleteRanker.rankNotes(q, allItems, const []);
    sw.stop();
    autocompleteTimes.add(sw.elapsedMicroseconds / 1000.0);
  }

  if (autocompleteTimes.isNotEmpty) {
    PerfProbe.record(
      'autocomplete.p95',
      percentile(autocompleteTimes, 95),
      'ms',
    );
  }
}

/// S6: Memory RSS check.
/// Records: `memory.rss`, `memory.maxRss`.
void runScenarioS6() {
  if (kIsWeb) return;
  try {
    final currentRssMb = ProcessInfo.currentRss / (1024 * 1024);
    final maxRssMb = ProcessInfo.maxRss / (1024 * 1024);
    PerfProbe.record('memory.rss', currentRssMb, 'MB');
    PerfProbe.record('memory.maxRss', maxRssMb, 'MB');
  } catch (_) {
    // ProcessInfo unsupported on some platforms
  }
}
