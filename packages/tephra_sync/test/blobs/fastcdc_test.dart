// © 2026 Tephra. All rights reserved.

import 'dart:math';
import 'dart:typed_data';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

Uint8List _createSeededBuffer(int size, int seed) {
  final rng = Random(seed);
  final buf = Uint8List(size);
  for (var i = 0; i < size; i++) {
    buf[i] = rng.nextInt(256);
  }
  return buf;
}

void main() {
  group('FastCDC tests', () {
    test('files <= 4 MiB produce exactly one chunk', () {
      final zeroBytes = Uint8List(0);
      expect(FastCdc.chunk(zeroBytes), equals([(0, 0)]));

      final smallBytes = Uint8List(100);
      expect(FastCdc.chunk(smallBytes), equals([(0, 100)]));

      final exactMax = Uint8List(FastCdc.singleBlobMax);
      expect(FastCdc.chunk(exactMax), equals([(0, FastCdc.singleBlobMax)]));
    });

    test('deterministic cuts for seeded 20 MiB buffer (golden constants guard)', () {
      final buffer = _createSeededBuffer(20 * 1024 * 1024, 42);
      final chunks = FastCdc.chunk(buffer);

      expect(chunks.length, greaterThan(5));

      // Calculate the cut offsets (s + length)
      final cutOffsets = chunks.map((c) => c.$1 + c.$2).take(5).toList();
      // FROZEN GOLDEN CONSTANTS: Regression guard protecting FastCDC chunking.
      expect(
        cutOffsets,
        equals([1421931, 2651818, 4067736, 5450421, 6519841]),
        reason: 'Frozen FastCDC cut offsets regression guard',
      );

      // Check all chunks except the last are within [min, max]
      for (var i = 0; i < chunks.length - 1; i++) {
        final len = chunks[i].$2;
        expect(
          len >= FastCdc.minChunkSize && len <= FastCdc.maxChunkSize,
          isTrue,
          reason:
              'Chunk $i length $len out of bounds [${FastCdc.minChunkSize}, ${FastCdc.maxChunkSize}]',
        );
      }

      // Check sum of chunk lengths equals buffer length
      final totalChunkBytes = chunks.fold<int>(0, (sum, c) => sum + c.$2);
      expect(totalChunkBytes, equals(buffer.length));
    });

    test('inserting 10 bytes at 5 MiB changes at most 3 chunks', () {
      final original = _createSeededBuffer(20 * 1024 * 1024, 42);
      final originalChunks = FastCdc.chunk(original);

      // Insert 10 bytes at 5 MiB (5,242,880)
      const insertOffset = 5 * 1024 * 1024;
      final inserted = Uint8List(original.length + 10);
      inserted.setRange(0, insertOffset, original);
      for (var i = 0; i < 10; i++) {
        inserted[insertOffset + i] = 0xEE;
      }
      inserted.setRange(
        insertOffset + 10,
        inserted.length,
        original,
        insertOffset,
      );

      final modifiedChunks = FastCdc.chunk(inserted);

      // Compare chunk boundaries before and after the modification
      // In CDC, chunks far after the insertion point re-align and match identical cut points
      // Count chunks whose contents differ
      // We can compare the sets of chunk hashes or cut boundaries
      var differingChunks = 0;
      var origIdx = 0;
      var modIdx = 0;

      while (origIdx < originalChunks.length &&
          modIdx < modifiedChunks.length) {
        final (origStart, origLen) = originalChunks[origIdx];
        final (modStart, modLen) = modifiedChunks[modIdx];

        if (origStart + origLen < insertOffset) {
          // Chunk is before insertion point: must be identical
          expect(origStart, equals(modStart));
          expect(origLen, equals(modLen));
          origIdx++;
          modIdx++;
        } else {
          // Check how many chunks differ until re-alignment
          final origCut = origStart + origLen;
          final modCut =
              modStart + modLen - 10; // normalize for the 10 inserted bytes

          if (origCut == modCut) {
            // Re-aligned!
            origIdx++;
            modIdx++;
          } else if (origCut < modCut) {
            differingChunks++;
            origIdx++;
          } else {
            differingChunks++;
            modIdx++;
          }
        }
      }

      expect(differingChunks, lessThanOrEqualTo(3));
    });
  });
}
