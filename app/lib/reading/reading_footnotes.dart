// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../l10n/app_localizations.dart';
import 'inline_text.dart';
import 'reading_blocks.dart';
import 'reading_scope.dart';

/// Collected footnote definitions and references.
final class FootnoteIndex {
  const FootnoteIndex({
    required this.numbers,
    required this.definitions,
    required this.referenceOrder,
    required this.firstReferenceOffsets,
    required this.inlineFootnotes,
  });

  final Map<String, int> numbers;
  final Map<String, MdFootnoteDefinition> definitions;
  final List<String> referenceOrder;
  final Map<String, int> firstReferenceOffsets;
  final Map<String, MdInlineFootnote> inlineFootnotes;

  bool get hasReferences => referenceOrder.isNotEmpty;
}

/// Builds the [FootnoteIndex] by walking the document in AST order.
FootnoteIndex buildFootnoteIndex(ParsedNote parsed) {
  final numbers = <String, int>{};
  final definitions = <String, MdFootnoteDefinition>{};
  final referenceOrder = <String>[];
  final firstReferenceOffsets = <String, int>{};
  final inlineFootnotes = <String, MdInlineFootnote>{};

  var nextNumber = 1;

  void walk(MdNode node) {
    if (node is MdFootnoteDefinition) {
      definitions[node.label] = node;
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node is MdFootnoteRef) {
      if (!numbers.containsKey(node.label)) {
        numbers[node.label] = nextNumber++;
        referenceOrder.add(node.label);
        firstReferenceOffsets[node.label] = node.start;
      }
    } else if (node is MdInlineFootnote) {
      final label = 'inline-${node.start}';
      if (!numbers.containsKey(label)) {
        numbers[label] = nextNumber++;
        referenceOrder.add(label);
        firstReferenceOffsets[label] = node.start;
        inlineFootnotes[label] = node;
      }
    }

    for (final child in node.children) {
      walk(child);
    }
  }

  walk(parsed.root);

  return FootnoteIndex(
    numbers: numbers,
    definitions: definitions,
    referenceOrder: referenceOrder,
    firstReferenceOffsets: firstReferenceOffsets,
    inlineFootnotes: inlineFootnotes,
  );
}

/// Renders the footnote section at the bottom of the reading view.
class FootnoteSectionView extends StatelessWidget {
  const FootnoteSectionView({super.key, required this.index});

  final FootnoteIndex index;

  @override
  Widget build(BuildContext context) {
    if (!index.hasReferences) {
      return const SizedBox.shrink();
    }

    final scope = ReadingScope.maybeOf(context);
    final theme = Theme.of(context);
    final styles = scope?.styles;
    final l10n = AppLocalizations.of(context);

    final items = <Widget>[];

    for (final label in index.referenceOrder) {
      final num = index.numbers[label]!;
      final refOffset = index.firstReferenceOffsets[label] ?? 0;

      final Widget content;
      if (label.startsWith('inline-') &&
          index.inlineFootnotes.containsKey(label)) {
        content = InlineText(nodes: index.inlineFootnotes[label]!.children);
      } else if (index.definitions.containsKey(label)) {
        final defNode = index.definitions[label]!;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: defNode.children
              .map((c) => buildBlock(context, c))
              .toList(),
        );
      } else {
        content = Text(
          l10n.footnoteMissing,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );
      }

      items.add(
        Padding(
          key: Key('footnote:$label'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$num.',
                  textAlign: TextAlign.right,
                  style: styles?.body ?? theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: content),
              IconButton(
                icon: const Text('↩', style: TextStyle(fontSize: 16)),
                tooltip: 'Back to reference',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  scope?.controller?.scrollToOffset(refOffset);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [const Divider(height: 32, thickness: 1), ...items],
    );
  }
}
