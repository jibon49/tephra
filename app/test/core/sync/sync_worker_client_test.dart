// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_messages.dart';
import 'package:tephra/core/sync/sync_worker_client.dart';

void main() {
  group('SyncWorkerClient', () {
    late ReceivePort fakeWorkerReceivePort;
    late StreamSubscription<dynamic> fakeWorkerSub;
    late SyncWorkerClient client;
    late List<SyncRequest> receivedRequests;
    late Completer<String> tokenRequested;

    setUp(() {
      fakeWorkerReceivePort = ReceivePort();
      receivedRequests = [];
      tokenRequested = Completer<String>();

      SendPort? clientPort;

      fakeWorkerSub = fakeWorkerReceivePort.listen((message) {
        if (message is SendPort) {
          clientPort = message;
          return;
        }

        if (message is SyncRequest) {
          receivedRequests.add(message);

          switch (message) {
            case final SyncNow req:
              clientPort?.send(
                WorkerReply(requestId: req.requestId, payload: null),
              );

            case final SetPaused req:
              clientPort?.send(
                WorkerReply(requestId: req.requestId, payload: true),
              );

            case final TokenReply reply:
              tokenRequested.complete(reply.token ?? '');

            case final Shutdown req:
              clientPort?.send(
                WorkerReply(requestId: req.requestId, payload: true),
              );

            default:
              clientPort?.send(
                WorkerReply(requestId: message.requestId, payload: true),
              );
          }
        }
      });

      client = SyncWorkerClient(
        workerSendPort: fakeWorkerReceivePort.sendPort,
        tokenHandler: (forceRefresh) async => 'fresh_token_xyz',
      );
    });

    tearDown(() async {
      await fakeWorkerSub.cancel();
      fakeWorkerReceivePort.close();
      await client.shutdown();
    });

    test('request and reply matching with SendPort', () async {
      // Connect client mainSendPort to fake worker
      fakeWorkerReceivePort.sendPort.send(client.mainSendPort);

      await client.setPaused(true);
      expect(receivedRequests.last, isA<SetPaused>());
      expect((receivedRequests.last as SetPaused).paused, isTrue);
    });

    test('token request round trip from worker to client and reply', () async {
      fakeWorkerReceivePort.sendPort.send(client.mainSendPort);

      // Worker sends TokenRequest to client
      client.mainSendPort.send(const TokenRequest(requestId: 999));

      // Client should invoke tokenHandler and send TokenReply back to worker
      final token = await tokenRequested.future.timeout(
        const Duration(seconds: 2),
      );
      expect(token, equals('fresh_token_xyz'));
    });

    test('status stream emits updates sent by worker', () async {
      final statuses = <SyncStatusSnapshot>[];
      final sub = client.statusStream.listen(statuses.add);

      const snapshot = SyncStatusSnapshot(
        state: SyncUiState.syncing,
        pendingLocalChanges: 3,
      );
      client.mainSendPort.send(const StatusUpdate(snapshot));

      // Wait a microtask
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(statuses.length, equals(1));
      expect(statuses.first.state, equals(SyncUiState.syncing));
      expect(statuses.first.pendingLocalChanges, equals(3));

      await sub.cancel();
    });

    test('shutdown sends Shutdown request and closes resources', () async {
      fakeWorkerReceivePort.sendPort.send(client.mainSendPort);

      await client.shutdown();
      expect(receivedRequests.any((r) => r is Shutdown), isTrue);
    });
  });
}
