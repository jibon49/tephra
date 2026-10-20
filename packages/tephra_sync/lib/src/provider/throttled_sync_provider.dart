// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_core/tephra_core.dart';

import 'quota.dart';
import 'remote_changes.dart';
import 'remote_object.dart';
import 'sync_provider.dart';

typedef DelayFn = Future<void> Function(Duration duration);

/// A [SyncProvider] wrapper that limits upload and download bandwidth
/// using token-bucket rate limiting.
class ThrottledSyncProvider implements SyncProvider {
  ThrottledSyncProvider(
    this._inner, {
    int upKiBps = 0,
    int downKiBps = 0,
    Clock clock = const SystemClock(),
    DelayFn? delay,
  }) : _upBucket = _TokenBucket(
         rateKiBps: upKiBps,
         clock: clock,
         delay: delay ?? (d) => Future<void>.delayed(d),
       ),
       _downBucket = _TokenBucket(
         rateKiBps: downKiBps,
         clock: clock,
         delay: delay ?? (d) => Future<void>.delayed(d),
       );

  final SyncProvider _inner;
  final _TokenBucket _upBucket;
  final _TokenBucket _downBucket;

  int get upKiBps => _upBucket.rateKiBps;
  int get downKiBps => _downBucket.rateKiBps;

  @override
  String get id => _inner.id;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> put(String key, List<int> bytes) async {
    await _upBucket.consume(bytes.length);
    await _inner.put(key, bytes);
  }

  @override
  Future<List<int>> get(String key) async {
    final result = await _inner.get(key);
    await _downBucket.consume(result.length);
    return result;
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<List<RemoteObject>> list(String prefix) => _inner.list(prefix);

  @override
  Future<RemoteChanges> changesSince(String? cursor) =>
      _inner.changesSince(cursor);

  @override
  Future<Quota?> quota() => _inner.quota();

  /// Closes underlying provider if supported.
  Future<void> close() async {
    // If the inner provider supports closing, invoke it
    try {
      await (_inner as dynamic).close();
    } on NoSuchMethodError {
      // Ignored if inner does not implement close
    }
  }
}

class _TokenBucket {
  _TokenBucket({
    required this.rateKiBps,
    required this.clock,
    required this.delay,
  }) {
    if (rateKiBps > 0) {
      final effectiveRate = rateKiBps < 16 ? 16 : rateKiBps;
      bytesPerSecond = effectiveRate * 1024;
      capacity = bytesPerSecond.toDouble();
      tokens = capacity;
      lastRefill = clock.now();
    } else {
      bytesPerSecond = 0;
      capacity = 0;
      tokens = 0;
      lastRefill = clock.now();
    }
  }

  final int rateKiBps;
  final Clock clock;
  final DelayFn delay;

  late final int bytesPerSecond;
  late final double capacity;
  late double tokens;
  late DateTime lastRefill;

  bool get isUnlimited => rateKiBps <= 0;

  void _refill() {
    if (isUnlimited) return;
    final now = clock.now();
    final elapsedSec = now.difference(lastRefill).inMicroseconds / 1000000.0;
    if (elapsedSec > 0) {
      tokens = min(capacity, tokens + elapsedSec * bytesPerSecond);
      lastRefill = now;
    }
  }

  Future<void> consume(int bytes) async {
    if (isUnlimited || bytes <= 0) return;

    var remaining = bytes;
    final maxChunk = max(1024, capacity.floor());

    while (remaining > 0) {
      _refill();
      final toConsume = min(remaining, maxChunk);

      if (tokens >= toConsume) {
        tokens -= toConsume;
        remaining -= toConsume;
      } else {
        final needed = toConsume - tokens;
        final waitSec = needed / bytesPerSecond;
        final waitDur = Duration(
          microseconds: max(1, (waitSec * 1000000).ceil()),
        );
        await delay(waitDur);
      }
    }
  }
}
