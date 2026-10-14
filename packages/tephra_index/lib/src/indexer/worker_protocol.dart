// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:tephra_vault/tephra_vault.dart';

import '../model/index_event.dart';
import '../model/index_options.dart';
import '../model/index_progress.dart';

/// Startup configuration sent to the worker isolate.
final class WorkerStartup {
  const WorkerStartup({
    required this.replyTo,
    required this.rootDir,
    required this.dbFile,
    required this.options,
  });

  final SendPort replyTo;
  final String rootDir;
  final String dbFile;
  final IndexOptions options;
}

/// Request sent from the main isolate to the worker isolate.
sealed class WorkerRequest {
  const WorkerRequest(this.id);

  final int id;
}

/// Request to reconcile the index against the filesystem.
final class ReconcileRequest extends WorkerRequest {
  const ReconcileRequest(super.id);
}

/// Request to incrementally apply a single vault change.
final class ChangeRequest extends WorkerRequest {
  const ChangeRequest(super.id, {required this.change});

  final VaultChange change;
}

/// Request to rebuild the index from scratch.
final class RebuildRequest extends WorkerRequest {
  const RebuildRequest(super.id);
}

/// Request to shut down the worker isolate cleanly.
final class ShutdownRequest extends WorkerRequest {
  const ShutdownRequest(super.id);
}

/// Reply sent from the worker isolate back to the main isolate.
sealed class WorkerReply {
  const WorkerReply();
}

/// Worker is initialized, database is open, and requests port is available.
final class WorkerReady extends WorkerReply {
  const WorkerReady({required this.requests, required this.needsFullIndex});

  final SendPort requests;
  final bool needsFullIndex;
}

/// Request completed successfully.
final class WorkerDone extends WorkerReply {
  const WorkerDone({required this.id});

  final int id;
}

/// Request failed with an exception.
final class WorkerFailed extends WorkerReply {
  const WorkerFailed({
    required this.id,
    required this.error,
    required this.stack,
  });

  final int id;
  final String error;
  final String stack;
}

/// Progress update during indexing.
final class WorkerProgress extends WorkerReply {
  const WorkerProgress(this.progress);

  final IndexProgress progress;
}

/// Notification of committed changes to the index.
final class WorkerEvent extends WorkerReply {
  const WorkerEvent(this.event);

  final IndexEvent event;
}

/// Log message from the worker isolate.
final class WorkerLog extends WorkerReply {
  const WorkerLog({required this.level, required this.message});

  final String level;
  final String message;
}
