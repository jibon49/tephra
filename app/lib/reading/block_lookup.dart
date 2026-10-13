// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/tephra_markdown.dart';

/// Finds the index of the top-level block containing or preceding [offset].
///
/// Returns `-1` if [blocks] is empty.
/// Returns `0` if [offset] is before the first block.
/// Otherwise returns the index of the last block with `block.start <= offset`.
int blockIndexForOffset(List<MdNode> blocks, int offset) {
  if (blocks.isEmpty) return -1;
  if (offset < blocks.first.start) return 0;

  var low = 0;
  var high = blocks.length - 1;
  var result = 0;

  while (low <= high) {
    final mid = low + ((high - low) >> 1);
    if (blocks[mid].start <= offset) {
      result = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return result;
}
