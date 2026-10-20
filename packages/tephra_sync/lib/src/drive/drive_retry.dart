// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

import 'drive_errors.dart';

final _log = Logger('sync.drive');

/// Retry runner for Google Drive API operations with full-jitter exponential backoff.
class DriveRetry {
  const DriveRetry({
    this.maxRetries = 6,
    this.requestTimeout = const Duration(seconds: 60),
    Random? random,
  }) : _random = random;

  final int maxRetries;
  final Duration requestTimeout;
  final Random? _random;

  Random get _effectiveRandom => _random ?? Random();

  /// Runs [operation] with timeout and retries according to Google Drive backoff guidelines.
  Future<T> run<T>(Future<T> Function() operation) async {
    int attempt = 0;
    while (true) {
      try {
        return await operation().timeout(requestTimeout);
      } catch (e, st) {
        if (!DriveErrors.isRetryable(e) || attempt >= maxRetries) {
          throw DriveErrors.mapToSyncException(e, st);
        }

        attempt++;
        final delay = _calculateDelay(attempt, e);
        _log.warning(
          'Drive operation failed (attempt $attempt/$maxRetries): $e. Backing off ${delay.inMilliseconds} ms',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  Duration _calculateDelay(int attempt, Object error) {
    // Check if error contains retry-after hint
    final maxBackoffSeconds = min(64, 1 << (attempt - 1));
    final jitterMillis = _effectiveRandom.nextInt(maxBackoffSeconds * 1000 + 1);
    return Duration(milliseconds: jitterMillis);
  }
}
