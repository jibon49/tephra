// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../index_exceptions.dart';
import '../model/index_event.dart';
import '../model/index_options.dart';
import '../model/index_progress.dart';
import 'index_runner.dart';
import 'index_worker.dart';
import 'worker_protocol.dart';

/// Index runner that offloads indexing and reconciliation to a long-lived background isolate.
final class IsolateIndexRunner implements IndexRunner {
  IsolateIndexRunner._({
    required this.rootDir,
    required this.dbFile,
    required this.options,
  }) {
    _queue = IndexRequestQueue(_executeTask);
  }

  /// Spawns the worker isolate and waits for it to become ready.
  static Future<IsolateIndexRunner> create({
    required String rootDir,
    required String dbFile,
    IndexOptions options = const IndexOptions(),
  }) async {
    final runner = IsolateIndexRunner._(
      rootDir: rootDir,
      dbFile: dbFile,
      options: options,
    );
    await runner._spawnWorker();
    return runner;
  }

  final String rootDir;
  final String dbFile;
  final IndexOptions options;

  static final Logger _logger = Logger('tephra.isolate_runner');
  static final Logger _workerLogger = Logger('index.worker');

  late final IndexRequestQueue _queue;
  final StreamController<IndexProgress> _progressController =
      StreamController<IndexProgress>.broadcast();
  final StreamController<IndexEvent> _eventsController =
      StreamController<IndexEvent>.broadcast();

  final Map<int, Completer<void>> _pending = <int, Completer<void>>{};

  Isolate? _isolate;
  ReceivePort? _replyPort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  SendPort? _requestsPort;
  Completer<void>? _shutdownExitCompleter;

  int _nextId = 1;
  bool _disposed = false;
  bool _workerDied = false;
  bool _permanentlyFailed = false;
  DateTime? _lastCrashTime;

  Future<WorkerReady> _spawnWorker() async {
    _replyPort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    final startup = WorkerStartup(
      replyTo: _replyPort!.sendPort,
      rootDir: rootDir,
      dbFile: dbFile,
      options: options,
    );

    _isolate = await Isolate.spawn(
      indexWorkerMain,
      startup,
      errorsAreFatal: false,
      onError: _errorPort!.sendPort,
      onExit: _exitPort!.sendPort,
    );

    final readyCompleter = Completer<WorkerReady>();

    _replyPort!.listen((msg) {
      if (msg is WorkerReady) {
        _requestsPort = msg.requests;
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete(msg);
        }
      } else if (msg is WorkerDone) {
        final comp = _pending.remove(msg.id);
        comp?.complete();
      } else if (msg is WorkerFailed) {
        final comp = _pending.remove(msg.id);
        comp?.completeError(IndexQueryException(msg.error));
      } else if (msg is WorkerProgress) {
        _progressController.add(msg.progress);
      } else if (msg is WorkerEvent) {
        _eventsController.add(msg.event);
      } else if (msg is WorkerLog) {
        final level = Level.LEVELS.firstWhere(
          (l) => l.name == msg.level,
          orElse: () => Level.INFO,
        );
        _workerLogger.log(level, msg.message);
      }
    });

    _errorPort!.listen((error) {
      _logger.severe('Worker isolate reported error: $error');
    });

    _exitPort!.listen((_) {
      if (_shutdownExitCompleter != null &&
          !_shutdownExitCompleter!.isCompleted) {
        _shutdownExitCompleter!.complete();
      }
      _handleWorkerExit();
    });

    return readyCompleter.future;
  }

  void _handleWorkerExit() {
    if (_disposed) return;

    _logger.severe('index worker exited unexpectedly');
    _requestsPort = null;
    _isolate = null;
    _replyPort?.close();
    _replyPort = null;
    _errorPort?.close();
    _errorPort = null;
    _exitPort?.close();
    _exitPort = null;

    const err = IndexQueryException('index worker stopped');
    for (final comp in _pending.values) {
      if (!comp.isCompleted) {
        comp.completeError(err);
      }
    }
    _pending.clear();

    final now = DateTime.now();
    if (_lastCrashTime != null &&
        now.difference(_lastCrashTime!).inSeconds < 60) {
      _permanentlyFailed = true;
    }
    _lastCrashTime = now;
    _workerDied = true;
  }

  Future<void> _executeTask(RunnerTask task) async {
    if (_disposed) {
      throw const IndexQueryException('index runner is closed');
    }
    if (_permanentlyFailed) {
      throw const IndexQueryException('index worker stopped');
    }
    if (_workerDied || _requestsPort == null) {
      await _spawnWorker();
      _workerDied = false;
    }

    final id = _nextId++;
    final completer = Completer<void>();
    _pending[id] = completer;

    final WorkerRequest req = switch (task) {
      ReconcileTask() => ReconcileRequest(id),
      ApplyTask(:final change) => ChangeRequest(id, change: change),
      RebuildTask() => RebuildRequest(id),
    };

    _requestsPort!.send(req);
    await completer.future;
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
    if (_disposed) return;
    _disposed = true;
    _queue.dispose();

    if (_requestsPort != null && _isolate != null) {
      _shutdownExitCompleter = Completer<void>();
      final id = _nextId++;
      try {
        _requestsPort!.send(ShutdownRequest(id));
        await _shutdownExitCompleter!.future.timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        _isolate?.kill(priority: Isolate.immediate);
      }
    } else {
      _isolate?.kill(priority: Isolate.immediate);
    }

    _requestsPort = null;
    _isolate = null;
    _replyPort?.close();
    _replyPort = null;
    _errorPort?.close();
    _errorPort = null;
    _exitPort?.close();
    _exitPort = null;

    await _progressController.close();
    await _eventsController.close();
  }
}
