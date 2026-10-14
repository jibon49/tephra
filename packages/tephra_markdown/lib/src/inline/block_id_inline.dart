// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import 'inline_parser.dart';

final class BlockIdResult {
  BlockIdResult(this.node, this.nextIndex);

  final MdBlockId node;
  final int nextIndex;
}

/// Tries to emit an Obsidian block ID at [index] if flagged by [ctx.blockIdRange].
BlockIdResult? parseBlockId({
  required String text,
  required int index,
  required OffsetMap map,
  required InlineContext ctx,
}) {
  final range = ctx.blockIdRange;
  if (range == null) return null;
  if (index != range.$1) return null;

  // The range starts with '^'
  final id = text.substring(range.$1 + 1, range.$2);
  final node = MdBlockId(
    map.toSource(range.$1),
    map.toSourceEnd(range.$2),
    id: id,
  );

  return BlockIdResult(node, range.$2);
}
