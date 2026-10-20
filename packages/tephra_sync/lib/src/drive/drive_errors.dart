// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tephra_core/tephra_core.dart';

import '../errors/sync_exceptions.dart';

/// Helper for classifying and mapping Google Drive API exceptions.
class DriveErrors {
  DriveErrors._();

  /// Extracts the error reason string from a [drive.DetailedApiRequestError] if present.
  static String? extractReason(Object error) {
    if (error is drive.DetailedApiRequestError) {
      if (error.errors.isNotEmpty) {
        return error.errors.first.reason;
      }
    }
    return null;
  }

  /// Returns true if [error] is considered retryable under Google Drive API policies.
  static bool isRetryable(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }

    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      final reason = extractReason(error);

      if (status == 429) return true;
      if (status == 403 &&
          (reason == 'userRateLimitExceeded' ||
              reason == 'rateLimitExceeded')) {
        return true;
      }
      if (status != null && status >= 500 && status <= 599) {
        return true;
      }
    }

    return false;
  }

  /// Maps an API error or network exception into a corresponding [SyncException].
  static SyncException mapToSyncException(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is SyncException) return error;

    if (error is SocketException) {
      return NetworkUnavailableException('Network connection failed: $error');
    }
    if (error is TimeoutException) {
      return NetworkUnavailableException('Request timed out: $error');
    }
    if (error is http.ClientException) {
      return NetworkUnavailableException('HTTP client error: $error');
    }

    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      final reason = extractReason(error);
      final msg = error.message ?? error.toString();

      if (status == 429 ||
          (status == 403 &&
              (reason == 'userRateLimitExceeded' ||
                  reason == 'rateLimitExceeded'))) {
        return RateLimitedException(message: 'Drive rate limit exceeded: $msg');
      }

      if (status == 403 && reason == 'storageQuotaExceeded') {
        return RemoteQuotaExceededException(
          'Drive storage quota exceeded: $msg',
        );
      }

      if (status == 403 &&
          (reason == 'insufficientPermissions' ||
              reason == 'forbidden' ||
              reason == 'accessNotConfigured')) {
        return AuthRevokedException('Drive authorization rejected: $msg');
      }

      if (status == 404) {
        return RemoteNotFoundException('Drive resource not found: $msg');
      }

      if (status != null && status >= 500) {
        return RemoteServerException(
          status,
          'Google Drive server error (HTTP $status): $msg',
        );
      }
    }

    return RemoteServerException(500, 'Unexpected Drive error: $error');
  }
}
