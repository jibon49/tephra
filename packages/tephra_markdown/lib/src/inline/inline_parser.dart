// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../note_models.dart';
import '../parser_options.dart';
import '../util/offset_map.dart';

/// Source text and source offset mapping for inline parsing.
final class InlineSource {
  InlineSource({required this.text, required this.map});

  final String text;
  final OffsetMap map;
}

/// Context passed to inline parsing rules.
final class InlineContext {
  InlineContext({
    required this.options,
    required this.definitions,
    this.inTableCell = false,
    this.blockIdRange,
  });

  final ParserOptions options;
  final Map<String, LinkDefinition> definitions;
  final bool inTableCell;
  final (int start, int end)? blockIdRange;

  InlineContext withInTableCell(bool inTableCell) => InlineContext(
    options: options,
    definitions: definitions,
    inTableCell: inTableCell,
    blockIdRange: blockIdRange,
  );
}

/// Parses inline markdown in [source] given [ctx].
///
/// In Step 01.7 this is a stub that emits a single [MdText] per leaf block
/// so block structure can be tested in isolation. Step 01.8 replaces the stub.
List<MdNode> parseInlines(InlineSource source, InlineContext ctx) {
  if (source.text.isEmpty) return const [];
  return [
    MdText(
      source.map.toSource(0),
      source.map.toSourceEnd(source.text.length),
      text: source.text,
    ),
  ];
}
