// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class FakeClock implements Clock {
  DateTime currentTime = DateTime.utc(2026, 10, 20, 10, 0, 0);

  @override
  DateTime now() => currentTime;
}

void main() {
  group('DesktopTokenSource', () {
    late HttpServer server;
    late Uri tokenEndpoint;
    late Uri revokeEndpoint;
    late MemorySecretStore store;
    late FakeClock clock;
    late DesktopOAuthFlow dummyFlow;

    int refreshRequestCount = 0;
    int revokeRequestCount = 0;
    String? lastRevokedToken;
    int responseStatusCode = 200;
    String responseBody = '';

    setUp(() async {
      refreshRequestCount = 0;
      revokeRequestCount = 0;
      lastRevokedToken = null;
      responseStatusCode = 200;
      responseBody = jsonEncode({
        'access_token': 'refreshed_access_token',
        'expires_in': 3600,
      });

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      tokenEndpoint = Uri.parse('http://127.0.0.1:${server.port}/token');
      revokeEndpoint = Uri.parse('http://127.0.0.1:${server.port}/revoke');

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/token') {
          refreshRequestCount++;
          request.response.statusCode = responseStatusCode;
          request.response.headers.contentType = ContentType.json;
          request.response.write(responseBody);
          await request.response.close();
        } else if (request.uri.path == '/revoke') {
          revokeRequestCount++;
          final body = await utf8.decoder.bind(request).join();
          final parsed = Uri.splitQueryString(body);
          lastRevokedToken = parsed['token'];
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      store = MemorySecretStore();
      clock = FakeClock();
      dummyFlow = DesktopOAuthFlow(
        clientId: 'test-client-id',
        clientSecret: 'test-client-secret',
        openBrowser: (_) async {},
      );
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'refreshes token when less than 2 minutes remain before expiry',
      () async {
        final tokenSource = DesktopTokenSource(
          flow: dummyFlow,
          store: store,
          clock: clock,
          tokenEndpoint: tokenEndpoint,
          revokeEndpoint: revokeEndpoint,
        );

        // Save initial tokens expiring in 1 minute (below 2 minute threshold)
        await tokenSource.saveTokens(
          OAuthTokens(
            accessToken: 'old_access_token',
            refreshToken: 'refresh_tok_1',
            expiresAt: clock.now().add(const Duration(minutes: 1)),
            scope: 'drive.file',
            email: 'user@example.com',
          ),
        );

        final token = await tokenSource.accessToken();
        expect(token, equals('refreshed_access_token'));
        expect(refreshRequestCount, equals(1));

        // Second call uses cached fresh token without refreshing
        final cachedToken = await tokenSource.accessToken();
        expect(cachedToken, equals('refreshed_access_token'));
        expect(refreshRequestCount, equals(1));
      },
    );

    test(
      'invalid_grant throws AuthRevokedException and purges stored secrets',
      () async {
        responseStatusCode = 400;
        responseBody = jsonEncode({
          'error': 'invalid_grant',
          'error_description': 'Token has been expired or revoked.',
        });

        final tokenSource = DesktopTokenSource(
          flow: dummyFlow,
          store: store,
          clock: clock,
          tokenEndpoint: tokenEndpoint,
        );

        await store.write(
          SyncSecretKeys.desktopRefreshToken,
          'revoked_refresh_token',
        );
        await store.write(SyncSecretKeys.accountEmail, 'user@example.com');

        await expectLater(
          tokenSource.accessToken(forceRefresh: true),
          throwsA(isA<AuthRevokedException>()),
        );

        expect(await store.read(SyncSecretKeys.desktopRefreshToken), isNull);
        expect(await store.read(SyncSecretKeys.accountEmail), isNull);
        expect(await store.read(SyncSecretKeys.accessToken), isNull);
      },
    );

    test('maps 500 server error to NetworkUnavailableException', () async {
      responseStatusCode = 500;
      responseBody = 'Internal Server Error';

      final tokenSource = DesktopTokenSource(
        flow: dummyFlow,
        store: store,
        clock: clock,
        tokenEndpoint: tokenEndpoint,
      );

      await store.write(SyncSecretKeys.desktopRefreshToken, 'some_token');

      await expectLater(
        tokenSource.accessToken(forceRefresh: true),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('signOut revokes token and clears stored secrets', () async {
      final tokenSource = DesktopTokenSource(
        flow: dummyFlow,
        store: store,
        clock: clock,
        tokenEndpoint: tokenEndpoint,
        revokeEndpoint: revokeEndpoint,
      );

      await tokenSource.saveTokens(
        OAuthTokens(
          accessToken: 'active_access_token',
          refreshToken: 'refresh_token_to_revoke',
          expiresAt: clock.now().add(const Duration(hours: 1)),
          scope: 'drive.file',
          email: 'user@example.com',
        ),
      );

      await tokenSource.signOut();

      expect(revokeRequestCount, equals(1));
      expect(lastRevokedToken, equals('refresh_token_to_revoke'));
      expect(await store.read(SyncSecretKeys.desktopRefreshToken), isNull);
      expect(await store.read(SyncSecretKeys.accessToken), isNull);
      expect(await store.read(SyncSecretKeys.accountEmail), isNull);
    });
  });
}
