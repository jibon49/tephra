// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/sync_exceptions.dart';
import 'access_token_source.dart';

/// An HTTP client that attaches an OAuth bearer token to outgoing requests
/// and retries on HTTP 401 with a refreshed token.
class AuthedClient extends http.BaseClient {
  AuthedClient({
    required this.inner,
    required this.tokenSource,
    this.closeInner = true,
  });

  final http.Client inner;
  final AccessTokenSource tokenSource;
  final bool closeInner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    final token = await tokenSource.accessToken();

    final req = _copyRequest(request, bodyBytes, token);
    final response = await inner.send(req);

    if (response.statusCode == 401) {
      final refreshedToken = await tokenSource.accessToken(forceRefresh: true);
      final retryReq = _copyRequest(request, bodyBytes, refreshedToken);
      final retryResponse = await inner.send(retryReq);

      if (retryResponse.statusCode == 401) {
        throw const AuthRevokedException(
          'HTTP 401 Unauthorized after token refresh',
        );
      }
      return retryResponse;
    }

    return response;
  }

  http.BaseRequest _copyRequest(
    http.BaseRequest original,
    Uint8List bodyBytes,
    String token,
  ) {
    final copy = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..headers['Authorization'] = 'Bearer $token'
      ..bodyBytes = bodyBytes
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;
    return copy;
  }

  @override
  void close() {
    if (closeInner) {
      inner.close();
    }
  }
}
