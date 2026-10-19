// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// FastCDC chunking algorithm ("fastcdc-gear32-v1").
///
/// Implements content-defined chunking using a 32-bit gear hash and two-level
/// normalized chunking (maskS / maskL) to balance chunk distribution.
abstract final class FastCdc {
  /// Minimum chunk size (256 KiB = 262,144 bytes).
  static const int minChunkSize = 262144;

  /// Target average chunk size (1 MiB = 1,048,576 bytes).
  static const int avgChunkSize = 1048576;

  /// Maximum chunk size (4 MiB = 4,194,304 bytes).
  static const int maxChunkSize = 4194304;

  /// Files <= this threshold are stored as a single chunk (4 MiB).
  static const int singleBlobMax = 4194304;

  /// Small mask (top 22 bits set): 0xFFFFFC00.
  static const int maskS = 0xFFFFFC00;

  /// Large mask (top 18 bits set): 0xFFFFC000.
  static const int maskL = 0xFFFFC000;

  /// Algorithm identifier recorded in vault.json.
  static const String algorithm = 'fastcdc-gear32-v1';

  /// Precomputed 256-entry Gear lookup table.
  ///
  /// gear[i] = the first 4 bytes (big-endian) of SHA-256 of UTF-8 `tephra-gear-v1-<i>`.
  static final Uint32List gear = _computeGearTable();

  static Uint32List _computeGearTable() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      final digest = crypto.sha256
          .convert(utf8.encode('tephra-gear-v1-$i'))
          .bytes;
      final val =
          ((digest[0] & 0xFF) << 24) |
          ((digest[1] & 0xFF) << 16) |
          ((digest[2] & 0xFF) << 8) |
          (digest[3] & 0xFF);
      table[i] = val;
    }
    return table;
  }

  /// Chunks [data] into a list of `(int offset, int length)` slices.
  ///
  /// - Files of size <= [singleBlobMax] (4 MiB) yield exactly one chunk: `[(0, data.length)]`.
  /// - Larger files are cut using FastCDC with min 256 KiB, avg 1 MiB, max 4 MiB.
  /// - Deterministic: identical bytes produce identical cuts on all platforms.
  static List<(int offset, int length)> chunk(
    List<int> data, {
    int min = minChunkSize,
    int avg = avgChunkSize,
    int max = maxChunkSize,
    int singleMax = singleBlobMax,
  }) {
    final totalLength = data.length;

    // Files <= singleBlobMax produce exactly one chunk
    if (totalLength <= singleMax) {
      return [(0, totalLength)];
    }

    final chunks = <(int, int)>[];
    var s = 0;

    while (s < totalLength) {
      final remaining = totalLength - s;
      if (remaining <= min) {
        chunks.add((s, remaining));
        break;
      }

      final chunkMax = remaining < max ? remaining : max;
      final chunkAvg = remaining < avg ? remaining : avg;

      var h = 0;
      var cutLen = -1;

      // 1. Check positions up to avg using maskS
      for (var offset = min; offset < chunkAvg; offset++) {
        final b = data[s + offset];
        h = ((h << 1) + gear[b]) & 0xFFFFFFFF;
        if ((h & maskS) == 0) {
          cutLen = offset + 1;
          break;
        }
      }

      // 2. Check positions from avg up to max using maskL
      if (cutLen == -1) {
        for (var offset = chunkAvg; offset < chunkMax; offset++) {
          final b = data[s + offset];
          h = ((h << 1) + gear[b]) & 0xFFFFFFFF;
          if ((h & maskL) == 0) {
            cutLen = offset + 1;
            break;
          }
        }
      }

      // 3. Force cut at max (or remaining if at EOF)
      if (cutLen == -1) {
        cutLen = chunkMax;
      }

      chunks.add((s, cutLen));
      s += cutLen;
    }

    return chunks;
  }
}
