// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_vault/tephra_vault.dart';

import '../index_exceptions.dart';
import '../model/index_event.dart';
import '../model/index_progress.dart';

/// Runner interface for executing index operations.
abstract interface class IndexRunner {
  /// Runs a reconcile against the vault filesystem.
  Future<void> reconcile();

  /// Incrementally applies a vault filesystem change.
  Future<void> apply(VaultChange c);

  /// Rebuilds the index database from scratch.
  Future<void> rebuild();

  /// Stream of indexer progress reports.
  Stream<IndexProgress> get progress;

  /// Stream of index change events.
  Stream<IndexEvent> get events;

  /// Disposes resources and stops any background workers.
  Future<void> dispose();
}

/// Task item in the runner's execution queue.
sealed class RunnerTask {
  final List<Completer<void>> completers = <Completer<void>>[];
}

/// Reconcile task.
final class ReconcileTask extends RunnerTask {}

/// Apply change task.
final class ApplyTask extends RunnerTask {
  ApplyTask(this.change);

  final VaultChange change;
}

/// Rebuild task.
final class RebuildTask extends RunnerTask {}

/// Execution queue ensuring FIFO operation order and consecutive apply coalescing.
final class IndexRequestQueue {
  IndexRequestQueue(this._executor);

  final Future<void> Function(RunnerTask task) _executor;
  final List<RunnerTask> _queue = <RunnerTask>[];
  RunnerTask? _currentTask;
  bool _running = false;
  bool _disposed = false;

  Future<void> enqueueReconcile() => _enqueue(ReconcileTask());

  Future<void> enqueueRebuild() => _enqueue(RebuildTask());

  Future<void> enqueueApply(VaultChange change) {
    if (_disposed) {
      throw const IndexQueryException('index runner is closed');
    }
    // Consecutive queued apply calls for the same path and same change type are coalesced (keep one).
    if (_queue.isNotEmpty && _queue.last is ApplyTask) {
      final lastApply = _queue.last as ApplyTask;
      if (_isSamePathAndType(lastApply.change, change)) {
        final c = Completer<void>();
        lastApply.completers.add(c);
        return c.future;
      }
    }
    return _enqueue(ApplyTask(change));
  }

  Future<void> _enqueue(RunnerTask task) {
    if (_disposed) {
      throw const IndexQueryException('index runner is closed');
    }
    final c = Completer<void>();
    task.completers.add(c);
    _queue.add(task);
    _drain();
    return c.future;
  }

  static bool _isSamePathAndType(VaultChange a, VaultChange b) {
    if (a.runtimeType != b.runtimeType) return false;
    if (a.path != b.path) return false;
    if (a is FileMoved && b is FileMoved) {
      return a.from == b.from;
    }
    return true;
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    while (_queue.isNotEmpty && !_disposed) {
      final task = _queue.removeAt(0);
      _currentTask = task;
      try {
        await _executor(task);
        for (final c in task.completers) {
          if (!c.isCompleted) c.complete();
        }
      } catch (e, st) {
        for (final c in task.completers) {
          if (!c.isCompleted) c.completeError(e, st);
        }
      } finally {
        _currentTask = null;
      }
    }
    _running = false;
  }

  void cancelAll([Object? error, StackTrace? stack]) {
    final err = error ?? const IndexQueryException('index runner cancelled');
    if (_currentTask != null) {
      for (final c in _currentTask!.completers) {
        if (!c.isCompleted) c.completeError(err, stack);
      }
      _currentTask = null;
    }
    for (final task in _queue) {
      for (final c in task.completers) {
        if (!c.isCompleted) c.completeError(err, stack);
      }
    }
    _queue.clear();
  }

  void dispose() {
    _disposed = true;
    cancelAll(const IndexQueryException('index runner is closed'));
  }
}
