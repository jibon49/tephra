// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../db/index_database.dart';
import '../model/index_event.dart';
import '../model/index_options.dart';
import '../model/index_progress.dart';
import 'index_runner.dart';
import 'indexer_core.dart';

/// Index runner that runs index operations in-process on the current isolate.
///
/// Used for in-memory databases and tests.
final class InProcessIndexRunner implements IndexRunner {
  InProcessIndexRunner({
    required TephraIndexDatabase db,
    required VaultFileSystem fs,
    Clock clock = const SystemClock(),
    IndexOptions options = const IndexOptions(),
  }) {
    _core = IndexerCore(
      db: db,
      fs: fs,
      clock: clock,
      options: options,
      onProgress: _progressController.add,
      onEvent: _eventsController.add,
    );
    _queue = IndexRequestQueue(_executeTask);
  }

  late final IndexerCore _core;
  late final IndexRequestQueue _queue;

  final StreamController<IndexProgress> _progressController =
      StreamController<IndexProgress>.broadcast();
  final StreamController<IndexEvent> _eventsController =
      StreamController<IndexEvent>.broadcast();

  IndexerCore get core => _core;

  Future<void> _executeTask(RunnerTask task) async {
    switch (task) {
      case ReconcileTask():
        await _core.reconcile();
      case ApplyTask(:final change):
        await _core.apply(change);
      case RebuildTask():
        await _core.rebuild();
    }
  }

  @override
  Future<void> reconcile() => _queue.enqueueReconcile();

  @override
  Future<void> apply(VaultChange c) => _queue.enqueueApply(c);

  @override
  Future<void> rebuild() => _queue.enqueueRebuild();

  @override
  Stream<IndexProgress> get progress => _progressController.stream;

  @override
  Stream<IndexEvent> get events => _eventsController.stream;

  @override
  Future<void> dispose() async {
    _queue.dispose();
    await _progressController.close();
    await _eventsController.close();
    await _core.db.close();
  }
}
