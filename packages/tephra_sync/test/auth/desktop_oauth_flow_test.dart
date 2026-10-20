// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('DesktopOAuthFlow', () {
    late HttpServer tokenServer;
    late Uri tokenEndpoint;
    Map<String, String>? lastTokenRequestBody;

    setUp(() async {
      tokenServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      tokenEndpoint = Uri.parse('http://127.0.0.1:${tokenServer.port}/token');

      tokenServer.listen((HttpRequest request) async {
        if (request.method == 'POST' && request.uri.path == '/token') {
          final body = await utf8.decoder.bind(request).join();
          final parsed = Uri.splitQueryString(body);
          lastTokenRequestBody = parsed;

          request.response.headers.contentType = ContentType.json;
          // ID token payload with email
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'email': 'testuser@example.com'})),
              )
              .replaceAll('=', '');
          final dummyIdToken = 'eyJhbGciOiJSUzI1NiJ9.$payload.dummySignature';

          request.response.write(
            jsonEncode({
              'access_token': 'fake_access_token_123',
              'refresh_token': 'fake_refresh_token_456',
              'expires_in': 3600,
              'scope':
                  'https://www.googleapis.com/auth/drive.file openid email',
              'id_token': dummyIdToken,
            }),
          );
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    });

    tearDown(() async {
      await tokenServer.close(force: true);
    });

    test(
      'success flow exchanges code and extracts email from id_token',
      () async {
        String? capturedChallenge;
        final flow = DesktopOAuthFlow(
          clientId: 'desktop-client-id.apps.googleusercontent.com',
          clientSecret: 'desktop-client-secret',
          tokenEndpoint: tokenEndpoint,
          openBrowser: (Uri authUri) async {
            capturedChallenge = authUri.queryParameters['code_challenge'];
            final redirectUri = authUri.queryParameters['redirect_uri']!;
            final state = authUri.queryParameters['state']!;

            // Perform redirect callback
            final response = await http.get(
              Uri.parse('$redirectUri?code=valid_auth_code&state=$state'),
            );
            expect(response.statusCode, equals(200));
            expect(response.body, contains('Tephra is connected'));
          },
        );

        final tokens = await flow.signIn();

        expect(tokens.accessToken, equals('fake_access_token_123'));
        expect(tokens.refreshToken, equals('fake_refresh_token_456'));
        expect(tokens.email, equals('testuser@example.com'));
        expect(tokens.scope, contains('drive.file'));
        expect(tokens.isExpired(), isFalse);

        // Verify token exchange request parameters
        expect(lastTokenRequestBody, isNotNull);
        expect(lastTokenRequestBody!['code'], equals('valid_auth_code'));
        expect(
          lastTokenRequestBody!['client_id'],
          equals('desktop-client-id.apps.googleusercontent.com'),
        );
        expect(
          lastTokenRequestBody!['client_secret'],
          equals('desktop-client-secret'),
        );
        expect(
          lastTokenRequestBody!['grant_type'],
          equals('authorization_code'),
        );

        // PKCE verification
        final verifier = lastTokenRequestBody!['code_verifier']!;
        final expectedChallenge = base64Url
            .encode(sha256.convert(ascii.encode(verifier)).bytes)
            .replaceAll('=', '');
        expect(expectedChallenge, equals(capturedChallenge));
      },
    );

    test('ignores wrong state and accepts correct state afterwards', () async {
      final flow = DesktopOAuthFlow(
        clientId: 'desktop-client-id',
        clientSecret: 'secret',
        tokenEndpoint: tokenEndpoint,
        openBrowser: (Uri authUri) async {
          final redirectUri = authUri.queryParameters['redirect_uri']!;
          final state = authUri.queryParameters['state']!;

          // 1. Send request with bad state
          final badResponse = await http.get(
            Uri.parse('$redirectUri?code=bad_code&state=wrong_state_val'),
          );
          expect(badResponse.statusCode, equals(400));

          // 2. Send request with valid state
          final goodResponse = await http.get(
            Uri.parse('$redirectUri?code=good_code&state=$state'),
          );
          expect(goodResponse.statusCode, equals(200));
        },
      );

      final tokens = await flow.signIn();
      expect(tokens.accessToken, equals('fake_access_token_123'));
      expect(lastTokenRequestBody!['code'], equals('good_code'));
    });

    test(
      'redirect with error=access_denied throws AuthRevokedException',
      () async {
        final flow = DesktopOAuthFlow(
          clientId: 'desktop-client-id',
          clientSecret: 'secret',
          tokenEndpoint: tokenEndpoint,
          openBrowser: (Uri authUri) async {
            final redirectUri = authUri.queryParameters['redirect_uri']!;
            final state = authUri.queryParameters['state']!;

            final response = await http.get(
              Uri.parse('$redirectUri?error=access_denied&state=$state'),
            );
            expect(response.statusCode, equals(200));
            expect(response.body, contains('Sign-in cancelled'));
          },
        );

        await expectLater(flow.signIn(), throwsA(isA<AuthRevokedException>()));
      },
    );

    test('timeout throws AuthRevokedException with timeout message', () async {
      final flow = DesktopOAuthFlow(
        clientId: 'desktop-client-id',
        clientSecret: 'secret',
        tokenEndpoint: tokenEndpoint,
        timeout: const Duration(milliseconds: 100),
        openBrowser: (_) async {
          // Do nothing to simulate user not completing sign-in
        },
      );

      await expectLater(
        flow.signIn(),
        throwsA(
          isA<AuthRevokedException>().having(
            (e) => e.message,
            'message',
            contains('timeout'),
          ),
        ),
      );
    });
  });
}
