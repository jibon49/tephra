// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tephra_core/tephra_core.dart';

import '../errors/sync_exceptions.dart';
import 'access_token_source.dart';
import 'desktop_oauth_flow.dart';
import 'oauth_tokens.dart';
import 'secret_store.dart';

/// Desktop access token source implementing in-memory & secure store caching,
/// automatic token refresh, and sign-out token revocation.
class DesktopTokenSource implements AccessTokenSource {
  DesktopTokenSource({
    required this.flow,
    required this.store,
    Clock? clock,
    http.Client? client,
    this.tokenEndpoint,
    this.revokeEndpoint,
  }) : clock = clock ?? const SystemClock(),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final DesktopOAuthFlow flow;
  final SecretStore store;
  final Clock clock;
  final http.Client _client;
  final bool _ownsClient;
  final Uri? tokenEndpoint;
  final Uri? revokeEndpoint;

  String? _cachedAccessToken;
  DateTime? _cachedExpiry;
  String? _cachedRefreshToken;
  String? _cachedEmail;

  /// Saves newly obtained [tokens] to memory cache and [store].
  Future<void> saveTokens(OAuthTokens tokens) async {
    _cachedAccessToken = tokens.accessToken;
    _cachedExpiry = tokens.expiresAt;
    _cachedRefreshToken = tokens.refreshToken;
    _cachedEmail = tokens.email;

    await store.write(SyncSecretKeys.accessToken, tokens.accessToken);
    await store.write(
      SyncSecretKeys.accessTokenExpiry,
      tokens.expiresAt.toIso8601String(),
    );
    await store.write(SyncSecretKeys.desktopRefreshToken, tokens.refreshToken);
    if (tokens.email != null) {
      await store.write(SyncSecretKeys.accountEmail, tokens.email!);
    }
  }

  /// Returns the current account email, if known.
  Future<String?> getAccountEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final stored = await store.read(SyncSecretKeys.accountEmail);
    if (stored != null && stored.isNotEmpty) {
      _cachedEmail = stored;
    }
    return _cachedEmail;
  }

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    final now = clock.now().toUtc();

    // 1. Check in-memory cached access token
    if (!forceRefresh &&
        _cachedAccessToken != null &&
        _cachedExpiry != null &&
        _cachedExpiry!.subtract(const Duration(minutes: 2)).isAfter(now)) {
      return _cachedAccessToken!;
    }

    // 2. Check stored token in SecretStore if memory was empty
    if (!forceRefresh && _cachedAccessToken == null) {
      final storedToken = await store.read(SyncSecretKeys.accessToken);
      final storedExpiryStr = await store.read(
        SyncSecretKeys.accessTokenExpiry,
      );
      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedExpiryStr != null) {
        final storedExpiry = DateTime.tryParse(storedExpiryStr)?.toUtc();
        if (storedExpiry != null &&
            storedExpiry.subtract(const Duration(minutes: 2)).isAfter(now)) {
          _cachedAccessToken = storedToken;
          _cachedExpiry = storedExpiry;
          return storedToken;
        }
      }
    }

    // 3. Token is expired or forceRefresh requested: refresh via refresh token
    return _refresh(now);
  }

  Future<String> _refresh(DateTime now) async {
    var refreshToken = _cachedRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      refreshToken = await store.read(SyncSecretKeys.desktopRefreshToken);
      _cachedRefreshToken = refreshToken;
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthRevokedException('No refresh token available');
    }

    final endpoint =
        tokenEndpoint ?? Uri.parse('https://oauth2.googleapis.com/token');

    http.Response response;
    try {
      response = await _client.post(
        endpoint,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': flow.clientId,
          'client_secret': flow.clientSecret,
        },
      );
    } on SocketException catch (e) {
      throw NetworkUnavailableException(
        'Failed to connect to token endpoint: $e',
      );
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('HTTP client error: $e');
    } on TimeoutException catch (e) {
      throw NetworkUnavailableException('Token refresh timed out: $e');
    }

    if (response.statusCode == 400 && response.body.contains('invalid_grant')) {
      await _deleteStoredTokens();
      throw AuthRevokedException('invalid_grant: ${response.body}');
    }

    if (response.statusCode != 200) {
      if (response.statusCode >= 500) {
        throw NetworkUnavailableException(
          'Token endpoint returned HTTP ${response.statusCode}',
        );
      }
      throw AuthRevokedException(
        'Token refresh failed: HTTP ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final newAccessToken = json['access_token'] as String?;
    final expiresIn = (json['expires_in'] as num?)?.toInt();
    final newRefreshToken = json['refresh_token'] as String?;

    if (newAccessToken == null || expiresIn == null) {
      throw const AuthRevokedException(
        'Invalid token refresh response payload',
      );
    }

    final newExpiry = now.add(Duration(seconds: expiresIn));
    _cachedAccessToken = newAccessToken;
    _cachedExpiry = newExpiry;
    await store.write(SyncSecretKeys.accessToken, newAccessToken);
    await store.write(
      SyncSecretKeys.accessTokenExpiry,
      newExpiry.toIso8601String(),
    );

    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      _cachedRefreshToken = newRefreshToken;
      await store.write(SyncSecretKeys.desktopRefreshToken, newRefreshToken);
    }

    return newAccessToken;
  }

  @override
  Future<void> signOut() async {
    final tokenToRevoke =
        _cachedRefreshToken ??
        await store.read(SyncSecretKeys.desktopRefreshToken);

    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      try {
        final endpoint =
            revokeEndpoint ?? Uri.parse('https://oauth2.googleapis.com/revoke');
        await _client.post(
          endpoint,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'token': tokenToRevoke},
        );
      } catch (_) {
        // Ignore revocation network failures during sign out
      }
    }

    await _deleteStoredTokens();
  }

  Future<void> _deleteStoredTokens() async {
    _cachedAccessToken = null;
    _cachedExpiry = null;
    _cachedRefreshToken = null;
    _cachedEmail = null;

    await store.delete(SyncSecretKeys.accessToken);
    await store.delete(SyncSecretKeys.accessTokenExpiry);
    await store.delete(SyncSecretKeys.desktopRefreshToken);
    await store.delete(SyncSecretKeys.accountEmail);
  }

  /// Closes underlying resources if owned.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
