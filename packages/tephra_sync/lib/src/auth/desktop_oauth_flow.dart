// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../errors/sync_exceptions.dart';
import 'oauth_tokens.dart';

/// Pure Dart OAuth 2.0 loopback + PKCE authorization flow for desktop platforms.
class DesktopOAuthFlow {
  DesktopOAuthFlow({
    required this.clientId,
    required this.clientSecret,
    required this.openBrowser,
    this.httpClient,
    Random? random,
    this.timeout = const Duration(minutes: 5),
    this.authorizationEndpoint,
    this.tokenEndpoint,
  }) : _random = random ?? Random.secure();

  final String clientId;
  final String clientSecret;
  final Future<void> Function(Uri) openBrowser;
  final http.Client? httpClient;
  final Random _random;
  final Duration timeout;
  final Uri? authorizationEndpoint;
  final Uri? tokenEndpoint;

  /// Runs the full interactive OAuth authorization flow.
  Future<OAuthTokens> signIn() async {
    // 1. Generate PKCE verifier, challenge and CSRF state
    final verifierBytes = List<int>.generate(64, (_) => _random.nextInt(256));
    final codeVerifier = _base64UrlUnpadded(verifierBytes);

    final challengeHash = sha256.convert(ascii.encode(codeVerifier)).bytes;
    final codeChallenge = _base64UrlUnpadded(challengeHash);

    final stateBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final state = _base64UrlUnpadded(stateBytes);

    // 2. Bind loopback server to an ephemeral port
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';

    // 3. Set up loopback redirect listener before launching browser
    final codeCompleter = Completer<String>();
    final subscription = server.listen((HttpRequest request) async {
      try {
        final reqState = request.uri.queryParameters['state'];
        if (reqState != state) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<html><body><h3>OAuth state mismatch</h3></body></html>',
          );
          await request.response.close();
          return;
        }

        if (request.uri.queryParameters.containsKey('error')) {
          final error = request.uri.queryParameters['error'];
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<html><body><h3>Sign-in cancelled. You can close this tab.</h3></body></html>',
          );
          await request.response.close();
          if (!codeCompleter.isCompleted) {
            codeCompleter.completeError(
              AuthRevokedException('Sign-in cancelled: $error'),
            );
          }
          return;
        }

        final code = request.uri.queryParameters['code'];
        if (code == null || code.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<html><body><h3>Missing authorization code</h3></body></html>',
          );
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<html><body><h3>Tephra is connected. You can close this tab and return to the app.</h3></body></html>',
        );
        await request.response.close();
        if (!codeCompleter.isCompleted) {
          codeCompleter.complete(code);
        }
      } catch (e, st) {
        if (!codeCompleter.isCompleted) {
          codeCompleter.completeError(e, st);
        }
      }
    });

    // 4. Construct Google authorization URL and open browser
    final authBase =
        authorizationEndpoint ??
        Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
    final authUri = authBase.replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'https://www.googleapis.com/auth/drive.file openid email',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );

    try {
      await openBrowser(authUri);
    } catch (e, st) {
      if (!codeCompleter.isCompleted) {
        codeCompleter.completeError(e, st);
      }
    }

    String code;
    try {
      code = await codeCompleter.future.timeout(
        timeout,
        onTimeout: () => throw const AuthRevokedException('timeout'),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }

    // 5. Exchange code for tokens
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;
    try {
      final endpoint =
          tokenEndpoint ?? Uri.parse('https://oauth2.googleapis.com/token');
      final response = await client.post(
        endpoint,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode != 200) {
        throw AuthRevokedException(
          'Failed to exchange authorization code: HTTP ${response.statusCode} ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String?;
      final refreshToken = json['refresh_token'] as String?;
      final expiresIn = (json['expires_in'] as num?)?.toInt();
      final scope = (json['scope'] as String?) ?? '';
      final idToken = json['id_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthRevokedException('Missing access_token');
      }
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const AuthRevokedException('Missing refresh_token');
      }
      if (expiresIn == null) {
        throw const AuthRevokedException('Missing expires_in');
      }

      final expiresAt = DateTime.now().toUtc().add(
        Duration(seconds: expiresIn),
      );
      String? email;
      if (idToken != null && idToken.isNotEmpty) {
        email = _extractEmailFromIdToken(idToken);
      }

      return OAuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        scope: scope,
        email: email,
      );
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  static String _base64UrlUnpadded(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static String? _extractEmailFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decodedBytes = base64Decode(payload);
      final payloadMap =
          jsonDecode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
      return payloadMap['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}
