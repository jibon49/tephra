// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

import '../../settings/vault_settings.dart';
import 'autocomplete_context.dart';
import 'autocomplete_item.dart';
import 'block_candidates.dart';
import 'slash_commands.dart';
import 'snippet_placement.dart';
import 'yaml_scalar.dart';

/// A template snippet with text and a relative caret position.
final class Snippet {
  const Snippet(this.text, {int? caret}) : caret = caret ?? text.length;

  final String text;
  final int caret;
}

/// The result of accepting an autocomplete suggestion.
final class Insertion {
  const Insertion(
    this.edits,
    this.caretAfter, {
    this.continueCompletion = false,
    this.sideEffects = const [],
  });

  final List<TextEdit> edits;
  final int caretAfter;
  final bool continueCompletion;
  final List<Future<void> Function()> sideEffects;
}

/// Builds an [Insertion] for link autocomplete contexts.
Insertion buildLinkInsertion(
  String text,
  AutocompleteContext ctx,
  AcItem item, {
  required LinkFormatter formatter,
  required VaultPath from,
  required bool continueIntoSubpath,
  VaultPath? targetNotePath,
  Set<String>? takenBlockIds,
  Random? rng,
  Future<void> Function(VaultPath target, BlockCandidate candidate, String id)?
  onExternalBlockCreated,
}) {
  final lineEndIdx = text.indexOf('\n', ctx.replaceEnd);
  final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
  final after = text.substring(ctx.replaceEnd, lineEnd);
  final closerPresent = after.startsWith(']]');
  final middleOfLink = !closerPresent && after.contains(']]');

  // --- Markdown Links Mode ---
  if (formatter.settings.useMarkdownLinks) {
    VaultPath path;
    String? alias;
    if (item.payload is VaultPath) {
      path = item.payload as VaultPath;
    } else if (item.payload is (VaultPath, String)) {
      final pair = item.payload as (VaultPath, String);
      path = pair.$1;
      alias = pair.$2;
    } else {
      path = from;
    }

    if (item.kind == AcKind.alias && alias == null) {
      alias = item.primary;
    }

    final isEmbed = ctx is NoteLinkContext && ctx.embed;
    final int openStart;
    if (ctx is NoteLinkContext) {
      openStart = ctx.openStart;
    } else if (ctx is HeadingLinkContext) {
      openStart = ctx.openStart;
    } else if (ctx is BlockLinkContext) {
      openStart = ctx.openStart;
    } else if (ctx is AliasLinkContext) {
      openStart = ctx.openStart;
    } else {
      openStart = ctx.replaceStart;
    }

    final replaceEnd = ctx.replaceEnd + (closerPresent ? 2 : 0);
    final linkStr = formatter.buildLink(
      path,
      from: from,
      embed: isEmbed,
      alias: alias,
    );

    final edit = TextEdit(openStart, replaceEnd, linkStr);
    return Insertion([edit], openStart + linkStr.length);
  }

  // --- Wiki Links Mode ---

  // 1. Note or Attachment
  if (ctx is NoteLinkContext) {
    final VaultPath path;
    String? alias;
    if (item.payload is (VaultPath, String)) {
      final pair = item.payload as (VaultPath, String);
      path = pair.$1;
      alias = pair.$2;
    } else if (item.payload is VaultPath) {
      path = item.payload as VaultPath;
      if (item.kind == AcKind.alias) {
        alias = item.primary;
      }
    } else {
      path = from;
    }

    final p = formatter.linkPath(path, from: from, syntax: LinkSyntax.wiki);
    final String contentToInsert;
    if (alias != null) {
      contentToInsert = '$p|$alias';
    } else {
      contentToInsert = p;
    }

    // Tab: continue into subpath (notes only, not aliases or attachments)
    if (continueIntoSubpath &&
        item.kind == AcKind.note &&
        alias == null &&
        !middleOfLink) {
      final String replacement;
      if (closerPresent) {
        replacement = '$contentToInsert#';
      } else {
        replacement = '$contentToInsert#]]';
      }
      final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
      final caretAfter = ctx.replaceStart + contentToInsert.length + 1;
      return Insertion([edit], caretAfter, continueCompletion: true);
    }

    // Enter / standard insertion
    final String replacement;
    final int caretAfter;
    if (middleOfLink) {
      replacement = contentToInsert;
      caretAfter = ctx.replaceStart + contentToInsert.length;
    } else if (closerPresent) {
      replacement = contentToInsert;
      caretAfter = ctx.replaceStart + contentToInsert.length + 2;
    } else {
      replacement = '$contentToInsert]]';
      caretAfter = ctx.replaceStart + contentToInsert.length + 2;
    }

    final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
    return Insertion([edit], caretAfter);
  }

  // 2. Heading
  if (ctx is HeadingLinkContext) {
    final headingText = LinkFormatter.sanitizeHeadingForLink(item.primary);
    final String replacement;
    final int caretAfter;

    if (middleOfLink) {
      replacement = headingText;
      caretAfter = ctx.replaceStart + headingText.length;
    } else if (closerPresent) {
      replacement = headingText;
      caretAfter = ctx.replaceStart + headingText.length + 2;
    } else {
      replacement = '$headingText]]';
      caretAfter = ctx.replaceStart + headingText.length + 2;
    }

    final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
    return Insertion([edit], caretAfter);
  }

  // 3. Alias in AliasLinkContext
  if (ctx is AliasLinkContext) {
    final aliasText = item.primary;
    final String replacement;
    final int caretAfter;

    if (middleOfLink) {
      replacement = aliasText;
      caretAfter = ctx.replaceStart + aliasText.length;
    } else if (closerPresent) {
      replacement = aliasText;
      caretAfter = ctx.replaceStart + aliasText.length + 2;
    } else {
      replacement = '$aliasText]]';
      caretAfter = ctx.replaceStart + aliasText.length + 2;
    }

    final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
    return Insertion([edit], caretAfter);
  }

  // 4. Block
  if (ctx is BlockLinkContext) {
    final BlockCandidate c;
    if (item.payload is BlockCandidate) {
      c = item.payload as BlockCandidate;
    } else {
      throw ArgumentError('Block item payload must be a BlockCandidate');
    }

    final taken = takenBlockIds ?? <String>{};
    final id = c.existingId ?? generateBlockId(rng ?? Random(), taken);

    // Determine replaceStart and prefix:
    // If the user typed [[Note^q, the replaceStart is right after '^' and text before has no '#'
    var linkReplaceStart = ctx.replaceStart;
    String prefix = '^$id';
    if (linkReplaceStart > 0 && text[linkReplaceStart - 1] == '^') {
      linkReplaceStart = linkReplaceStart - 1;
      if (linkReplaceStart < 1 || text[linkReplaceStart - 1] != '#') {
        prefix = '#^$id';
      }
    }

    final String linkReplacement;
    final int oldLinkCaret;
    if (middleOfLink) {
      linkReplacement = prefix;
      oldLinkCaret = linkReplaceStart + prefix.length;
    } else if (closerPresent) {
      linkReplacement = prefix;
      oldLinkCaret = linkReplaceStart + prefix.length + 2;
    } else {
      linkReplacement = '$prefix]]';
      oldLinkCaret = linkReplaceStart + prefix.length + 2;
    }

    final linkEdit = TextEdit(
      linkReplaceStart,
      ctx.replaceEnd,
      linkReplacement,
    );

    // If block already had an ID, no side effects needed
    if (c.existingId != null) {
      return Insertion([linkEdit], oldLinkCaret);
    }

    // Side effect needed:
    final targetPath = targetNotePath ?? from;
    final isCurrentNote = targetPath == from;

    if (isCurrentNote) {
      final idEdit = blockIdEdit(text, c, id);
      final List<TextEdit> edits;
      final int caretAfter;

      if (idEdit.start <= linkEdit.start) {
        edits = [idEdit, linkEdit];
        final delta = idEdit.replacement.length - (idEdit.end - idEdit.start);
        caretAfter = oldLinkCaret + delta;
      } else {
        edits = [linkEdit, idEdit];
        caretAfter = oldLinkCaret;
      }

      return Insertion(edits, caretAfter);
    } else {
      final sideEffects = <Future<void> Function()>[];
      if (onExternalBlockCreated != null) {
        sideEffects.add(() => onExternalBlockCreated(targetPath, c, id));
      }
      return Insertion([linkEdit], oldLinkCaret, sideEffects: sideEffects);
    }
  }

  // Fallback
  final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, item.primary);
  return Insertion([edit], ctx.replaceStart + item.primary.length);
}

/// Builds an [Insertion] for tag autocomplete context.
Insertion buildTagInsertion(String text, TagContext ctx, AcItem item) {
  final String tagText;
  if (item.payload is TagCount) {
    tagText = (item.payload as TagCount).tag;
  } else {
    tagText = item.primary.startsWith('#')
        ? item.primary.substring(1)
        : item.primary;
  }

  final String replacement;
  if (ctx.inFrontmatter) {
    replacement = yamlScalarForInsert(tagText);
  } else {
    replacement = tagText;
  }

  final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
  return Insertion([edit], ctx.replaceStart + replacement.length);
}

/// Builds an [Insertion] for property key autocomplete context.
Insertion buildPropertyKeyInsertion(
  String text,
  PropertyKeyContext ctx,
  AcItem item,
) {
  final String key;
  final String? valueType;
  if (item.payload is PropertyKeyCount) {
    final pkc = item.payload as PropertyKeyCount;
    key = pkc.key;
    valueType = pkc.valueType;
  } else {
    key = item.primary;
    valueType = item.secondary;
  }

  final keyLower = key.toLowerCase();
  final isListKey =
      valueType == 'multitext' ||
      valueType == 'tags' ||
      valueType == 'aliases' ||
      keyLower == 'tags' ||
      keyLower == 'aliases' ||
      keyLower == 'cssclasses';

  final String replacement;
  if (isListKey) {
    replacement = '$key:\n  - ';
  } else {
    replacement = '$key: ';
  }

  final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
  return Insertion(
    [edit],
    ctx.replaceStart + replacement.length,
    continueCompletion: true,
  );
}

/// Builds an [Insertion] for property value autocomplete context.
Insertion buildPropertyValueInsertion(
  String text,
  PropertyValueContext ctx,
  AcItem item, {
  String? keyType,
}) {
  final String rawVal;
  if (item.payload is TagCount) {
    rawVal = (item.payload as TagCount).tag;
  } else if (item.payload is String) {
    rawVal = item.payload as String;
  } else {
    rawVal = item.primary.startsWith('#')
        ? item.primary.substring(1)
        : item.primary;
  }

  final replacement = yamlScalarForInsert(rawVal, keyType: keyType);
  final edit = TextEdit(ctx.replaceStart, ctx.replaceEnd, replacement);
  return Insertion([edit], ctx.replaceStart + replacement.length);
}

/// General entry point to build an [Insertion] across any autocomplete context.
Insertion buildInsertion(
  String text,
  AutocompleteContext ctx,
  AcItem item, {
  required LinkFormatter formatter,
  required VaultPath from,
  required bool continueIntoSubpath,
  VaultPath? targetNotePath,
  Set<String>? takenBlockIds,
  Random? rng,
  Future<void> Function(VaultPath target, BlockCandidate candidate, String id)?
  onExternalBlockCreated,
  String? propertyKeyType,
  SlashInput? slashInput,
}) {
  if (ctx is SlashContext) {
    final cmd = item.payload as SlashCommand;
    final input =
        slashInput ??
        SlashInput(
          now: DateTime.now(),
          settings: const VaultSettings(),
          isLineZero: _isLineZero(text, ctx.slashStart),
        );
    final snippet = cmd.build(input);
    return placeSlash(text, ctx, cmd, snippet);
  }
  if (ctx is TagContext) {
    return buildTagInsertion(text, ctx, item);
  }
  if (ctx is PropertyKeyContext) {
    return buildPropertyKeyInsertion(text, ctx, item);
  }
  if (ctx is PropertyValueContext) {
    return buildPropertyValueInsertion(
      text,
      ctx,
      item,
      keyType: propertyKeyType,
    );
  }
  return buildLinkInsertion(
    text,
    ctx,
    item,
    formatter: formatter,
    from: from,
    continueIntoSubpath: continueIntoSubpath,
    targetNotePath: targetNotePath,
    takenBlockIds: takenBlockIds,
    rng: rng,
    onExternalBlockCreated: onExternalBlockCreated,
  );
}

bool _isLineZero(String text, int offset) {
  for (var i = offset - 1; i >= 0; i--) {
    if (text.codeUnitAt(i) == 0x0A) return false;
  }
  return true;
}
