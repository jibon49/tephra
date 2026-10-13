// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Tokens representing syntactic constructs in Markdown for Source mode highlighting.
enum SourceToken {
  text,
  headingMarker,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  strong,
  emphasis,
  strikethrough,
  highlight,
  emphasisMarker,
  inlineCode,
  codeBlock,
  codeFence,
  wikiBracket,
  wikiTarget,
  linkText,
  linkUrl,
  autolink,
  tag,
  blockId,
  comment,
  quoteMarker,
  quote,
  listMarker,
  taskBox,
  html,
  mathInline,
  mathBlock,
  frontmatter,
  footnote,
  tableBorder,
  tableHeader,
  thematicBreak,
  calloutMarker,
  findMatch,
  findCurrent,
}

/// Computes the [TextStyle] for a given [SourceToken] given [theme] and [base].
TextStyle styleFor(SourceToken t, ThemeData theme, TextStyle base) {
  final colorScheme = theme.colorScheme;
  final dimmedVariant = colorScheme.onSurfaceVariant.withValues(alpha: 0.70);

  switch (t) {
    case SourceToken.text:
      return base;

    case SourceToken.heading1:
    case SourceToken.heading2:
      return base.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.primary,
      );

    case SourceToken.heading3:
    case SourceToken.heading4:
    case SourceToken.heading5:
    case SourceToken.heading6:
      return base.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      );

    case SourceToken.headingMarker:
    case SourceToken.emphasisMarker:
    case SourceToken.wikiBracket:
    case SourceToken.linkUrl:
    case SourceToken.blockId:
    case SourceToken.quoteMarker:
    case SourceToken.codeFence:
    case SourceToken.tableBorder:
    case SourceToken.thematicBreak:
    case SourceToken.html:
    case SourceToken.frontmatter:
      return base.copyWith(color: dimmedVariant);

    case SourceToken.comment:
      return base.copyWith(color: dimmedVariant, fontStyle: FontStyle.italic);

    case SourceToken.strong:
      return base.copyWith(fontWeight: FontWeight.w700);

    case SourceToken.emphasis:
      return base.copyWith(fontStyle: FontStyle.italic);

    case SourceToken.strikethrough:
      return base.copyWith(decoration: TextDecoration.lineThrough);

    case SourceToken.highlight:
      return base.copyWith(backgroundColor: colorScheme.tertiaryContainer);

    case SourceToken.inlineCode:
    case SourceToken.codeBlock:
    case SourceToken.mathInline:
    case SourceToken.mathBlock:
      return base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.50,
        ),
      );

    case SourceToken.wikiTarget:
    case SourceToken.linkText:
    case SourceToken.autolink:
    case SourceToken.footnote:
      return base.copyWith(color: colorScheme.primary);

    case SourceToken.tag:
      return base.copyWith(
        color: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.40),
      );

    case SourceToken.listMarker:
      return base.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w700,
      );

    case SourceToken.taskBox:
      return base.copyWith(color: colorScheme.primary);

    case SourceToken.quote:
      return base.copyWith(fontStyle: FontStyle.italic);

    case SourceToken.tableHeader:
      return base.copyWith(fontWeight: FontWeight.w700);

    case SourceToken.calloutMarker:
      return base.copyWith(
        color: colorScheme.tertiary,
        fontWeight: FontWeight.w700,
      );

    case SourceToken.findMatch:
      return base.copyWith(backgroundColor: colorScheme.tertiaryContainer);

    case SourceToken.findCurrent:
      return base.copyWith(
        backgroundColor: colorScheme.tertiary.withValues(alpha: 0.55),
      );
  }
}
