// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

class FakeTokenSource implements AccessTokenSource {
  FakeTokenSource({required this.tokens});

  final List<String> tokens;
  int callIndex = 0;
  int refreshCount = 0;

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshCount++;
    }
    final token = tokens[callIndex.clamp(0, tokens.length - 1)];
    callIndex++;
    return token;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  group('AuthedClient', () {
    test('attaches Authorization header to requests', () async {
      final tokenSource = FakeTokenSource(tokens: ['valid_token']);
      final inner = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer valid_token'));
        return http.Response('ok', 200);
      });

      final authedClient = AuthedClient(inner: inner, tokenSource: tokenSource);

      final response = await authedClient.get(
        Uri.parse('https://example.com/api'),
      );
      expect(response.statusCode, equals(200));
      expect(response.body, equals('ok'));
    });

    test('401 triggers refresh and retry succeeds', () async {
      final tokenSource = FakeTokenSource(
        tokens: ['expired_token', 'fresh_token'],
      );

      int attempt = 0;
      final inner = MockClient((request) async {
        attempt++;
        if (attempt == 1) {
          expect(
            request.headers['Authorization'],
            equals('Bearer expired_token'),
          );
          return http.Response('Unauthorized', 401);
        } else {
          expect(
            request.headers['Authorization'],
            equals('Bearer fresh_token'),
          );
          return http.Response(jsonEncode({'result': 'success'}), 200);
        }
      });

      final authedClient = AuthedClient(inner: inner, tokenSource: tokenSource);

      final response = await authedClient.post(
        Uri.parse('https://example.com/api/upload'),
        body: 'payload data',
      );

      expect(response.statusCode, equals(200));
      expect(attempt, equals(2));
      expect(tokenSource.refreshCount, equals(1));
    });

    test('401 twice throws AuthRevokedException', () async {
      final tokenSource = FakeTokenSource(
        tokens: ['expired_token', 'still_invalid_token'],
      );

      final inner = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final authedClient = AuthedClient(inner: inner, tokenSource: tokenSource);

      expect(
        () => authedClient.get(Uri.parse('https://example.com/api/data')),
        throwsA(isA<AuthRevokedException>()),
      );
    });
  });
}
