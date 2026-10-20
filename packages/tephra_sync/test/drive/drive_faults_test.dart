// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import '../support/fake_drive_server.dart';

class StubAccessTokenSource implements AccessTokenSource {
  @override
  Future<String> accessToken({bool forceRefresh = false}) async => 'stub_token';

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeDriveServer server;
  late StubAccessTokenSource tokenSource;

  setUp(() async {
    server = FakeDriveServer();
    await server.start();
    tokenSource = StubAccessTokenSource();
  });

  tearDown(() async {
    await server.close();
  });

  DriveSyncProvider createProvider({
    int maxRetries = 6,
    Duration timeout = const Duration(seconds: 2),
  }) {
    return DriveSyncProvider(
      vaultId: 'v_faults',
      vaultName: 'Fault Vault',
      tokenSource: tokenSource,
      rootUrl: server.rootUrl,
      createIfMissing: true,
      retry: DriveRetry(
        maxRetries: maxRetries,
        requestTimeout: timeout,
        random: Random(42),
      ),
    );
  }

  group('DriveSyncProvider Fault Injection', () {
    test('429 rate limit retries 3 times then succeeds', () async {
      final provider = createProvider();
      await provider.connect();

      // Configure server to fail next 3 requests with HTTP 429
      server.faults.failNextRequests = 3;
      server.faults.statusCode = 429;
      server.faults.reason = 'rateLimitExceeded';

      await provider.put('devices/dev1.json', [1, 2, 3]);

      final bytes = await provider.get('devices/dev1.json');
      expect(bytes, equals([1, 2, 3]));
      expect(server.faults.failNextRequests, equals(0));
    });

    test('403 userRateLimitExceeded exceeds max retries and throws RateLimitedException', () async {
      final provider = createProvider(maxRetries: 3);
      await provider.connect();

      server.faults.failNextRequests = 10;
      server.faults.statusCode = 403;
      server.faults.reason = 'userRateLimitExceeded';

      await expectLater(
        provider.put('devices/dev1.json', [1]),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('500 server error retries and succeeds', () async {
      final provider = createProvider();
      await provider.connect();

      server.faults.failNextRequests = 2;
      server.faults.statusCode = 500;
      server.faults.reason = 'backendError';

      await provider.put('snapshots/dev1/s.snap', [42]);
      expect(await provider.get('snapshots/dev1/s.snap'), equals([42]));
    });

    test('timeout triggers retry and maps to NetworkUnavailableException on exhaustion', () async {
      final provider = createProvider(
        maxRetries: 2,
        timeout: const Duration(milliseconds: 50),
      );
      await provider.connect();

      // Incur a 200 ms delay on every request to trigger 50 ms timeout
      server.faults.delay = const Duration(milliseconds: 200);

      await expectLater(
        provider.put('devices/dev1.json', [1]),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('403 storageQuotaExceeded throws RemoteQuotaExceededException with no retry', () async {
      final provider = createProvider();
      await provider.connect();

      server.faults.failNextRequests = 5;
      server.faults.statusCode = 403;
      server.faults.reason = 'storageQuotaExceeded';

      await expectLater(
        provider.put('devices/dev1.json', [1]),
        throwsA(isA<RemoteQuotaExceededException>()),
      );
    });

    test('revoked token throws AuthRevokedException', () async {
      final provider = createProvider();
      await provider.connect();

      server.faults.revokeToken = true;

      await expectLater(
        provider.get('vault.json'),
        throwsA(isA<AuthRevokedException>()),
      );
    });
  });
}
