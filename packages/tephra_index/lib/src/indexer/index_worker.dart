// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../db/open_index_database.dart';
import 'indexer_core.dart';
import 'worker_protocol.dart';

/// Top-level entry point for the indexer worker isolate.
Future<void> indexWorkerMain(WorkerStartup s) async {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.INFO;

  final logSub = Logger.root.onRecord.listen((record) {
    try {
      s.replyTo.send(
        WorkerLog(level: record.level.name, message: record.message),
      );
    } catch (_) {}
  });

  OpenedIndexDatabase? opened;
  ReceivePort? requestsPort;

  try {
    opened = await openIndexDatabase(s.dbFile);
    final fs = IoVaultFileSystem(s.rootDir);
    final core = IndexerCore(
      db: opened.db,
      fs: fs,
      clock: const SystemClock(),
      options: s.options,
      onProgress: (p) {
        try {
          s.replyTo.send(WorkerProgress(p));
        } catch (_) {}
      },
      onEvent: (e) {
        try {
          s.replyTo.send(WorkerEvent(e));
        } catch (_) {}
      },
    );

    await core.loadNameTable();

    requestsPort = ReceivePort();
    s.replyTo.send(
      WorkerReady(
        requests: requestsPort.sendPort,
        needsFullIndex: opened.needsFullIndex,
      ),
    );

    await for (final message in requestsPort) {
      if (message is! WorkerRequest) continue;

      if (message is ShutdownRequest) {
        try {
          await opened.db.close();
          await logSub.cancel();
          requestsPort.close();
        } catch (_) {}
        Isolate.exit();
      }

      try {
        if (message is ReconcileRequest) {
          await core.reconcile();
        } else if (message is ChangeRequest) {
          await core.apply(message.change);
        } else if (message is RebuildRequest) {
          await core.rebuild();
        }
        s.replyTo.send(WorkerDone(id: message.id));
      } catch (e, st) {
        s.replyTo.send(
          WorkerFailed(
            id: message.id,
            error: e.toString(),
            stack: st.toString(),
          ),
        );
      }
    }
  } catch (e, st) {
    try {
      s.replyTo.send(
        WorkerFailed(id: -1, error: e.toString(), stack: st.toString()),
      );
    } catch (_) {}
    if (requestsPort != null) requestsPort.close();
    if (opened != null) {
      try {
        await opened.db.close();
      } catch (_) {}
    }
    await logSub.cancel();
  }
}
