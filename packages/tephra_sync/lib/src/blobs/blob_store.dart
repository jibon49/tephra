// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:typed_data';

import 'package:tephra_core/tephra_core.dart';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../errors/crypto_exceptions.dart';
import '../provider/sync_provider.dart';
import '../remote/remote_layout.dart';
import '../store/sync_state_store.dart';
import 'fastcdc.dart';

/// Concurrency limiter restricting parallel async transfers to [maxCount].
final class _TransferSemaphore {
  _TransferSemaphore(this.maxCount) : _available = maxCount;

  final int maxCount;
  int _available;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() action) async {
    if (_available <= 0) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _available--;
    try {
      return await action();
    } finally {
      _available++;
      if (_waiters.isNotEmpty) {
        final next = _waiters.removeAt(0);
        next.complete();
      }
    }
  }
}

/// Content-addressed remote blob store with FastCDC chunking, deduplication,
/// and end-to-end integrity verification.
final class BlobStore {
  /// Creates a [BlobStore].
  BlobStore({
    required this.provider,
    required this.cipher,
    required this.store,
    this.clock = const SystemClock(),
  });

  /// The underlying remote storage provider.
  final SyncProvider provider;

  /// Cipher for sealing and opening blob envelopes.
  final ObjectCipher cipher;

  /// Local sync state database store.
  final SyncStateStore store;

  /// Clock for timestamps.
  final Clock clock;

  /// Max 4 concurrent transfer calls to provider.
  final _TransferSemaphore _semaphore = _TransferSemaphore(4);

  /// 24 hours cache TTL for skipping remote presence confirmation.
  static const int _staleThresholdMs = 24 * 60 * 60 * 1000;

  /// Chunks, encrypts, deduplicates and uploads [bytes].
  ///
  /// Returns the ordered list of remote blob keys composing the file.
  Future<List<String>> putFile(
    List<int> bytes, {
    required String plainHash,
  }) async {
    final chunks = FastCdc.chunk(bytes);
    final blobKeys = <String>[];
    final now = clock.now().toUtc().millisecondsSinceEpoch;

    for (final chunkInfo in chunks) {
      final offset = chunkInfo.$1;
      final length = chunkInfo.$2;
      final chunkBytes = bytes is Uint8List
          ? Uint8List.sublistView(bytes, offset, offset + length)
          : Uint8List.fromList(bytes.sublist(offset, offset + length));

      final chunkHash =
          (chunks.length == 1 && offset == 0 && length == bytes.length)
          ? plainHash
          : contentHash(chunkBytes);

      // Check deduplication index
      final existing = await store.blobRecordForPlainHash(chunkHash);
      if (existing != null) {
        if (existing.seenAt >= now - _staleThresholdMs) {
          // Confirmed within last 24h: reuse
          blobKeys.add(existing.blobKey);
          continue;
        }

        // Stale: verify remote existence
        final listed = await _semaphore.run(
          () => provider.list(existing.blobKey),
        );
        if (listed.any((obj) => obj.key == existing.blobKey)) {
          // Still present remotely: touch and reuse
          await store.touchBlob(existing.blobKey, now);
          blobKeys.add(existing.blobKey);
          continue;
        } else {
          // Deleted remotely: remove stale entry and re-upload
          await store.removeBlobRecord(chunkHash, existing.blobKey);
        }
      }

      // Seal and upload chunk
      final stored = await cipher.seal(chunkBytes, ObjectPurpose.blob);
      final storedHash = contentHash(stored);
      final key = RemoteLayout.blob(storedHash);

      await _semaphore.run(() => provider.put(key, stored));
      await store.putBlobIndex(chunkHash, key, chunkBytes.length, now);
      blobKeys.add(key);
    }

    return blobKeys;
  }

  /// Downloads, verifies, decrypts, and concatenates the chunks in [blobKeys].
  ///
  /// Verifies individual blob hashes against key names and verifies assembled
  /// file content against [expectedPlainHash]. Throws [TamperedDataException]
  /// on any integrity mismatch.
  Future<List<int>> getFile(
    List<String> blobKeys, {
    required String expectedPlainHash,
  }) async {
    final builder = BytesBuilder(copy: false);
    final now = clock.now().toUtc().millisecondsSinceEpoch;

    for (final key in blobKeys) {
      final parsed = RemoteLayout.parse(key);
      if (parsed is! BlobKey) {
        throw TamperedDataException(
          key: key,
          message: 'Invalid blob key format: $key',
        );
      }

      final stored = await _semaphore.run(() => provider.get(key));
      final actualStoredHash = contentHash(stored);
      if (actualStoredHash.toLowerCase() != parsed.hash.toLowerCase()) {
        throw TamperedDataException(
          key: key,
          message: 'Stored blob hash mismatch for key: $key',
        );
      }

      final chunkBytes = await cipher.open(stored, ObjectPurpose.blob);
      builder.add(chunkBytes);

      // Record plaintext hash to blob key mapping in local deduplication index
      final chunkHash = contentHash(chunkBytes);
      await store.putBlobIndex(chunkHash, key, chunkBytes.length, now);
    }

    final all = builder.takeBytes();
    final actualPlainHash = contentHash(all);
    if (actualPlainHash.toLowerCase() != expectedPlainHash.toLowerCase()) {
      throw TamperedDataException(
        message:
            'Reassembled file hash ($actualPlainHash) does not match expected plain hash ($expectedPlainHash)',
      );
    }

    return all;
  }
}
