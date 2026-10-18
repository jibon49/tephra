// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Indicates whether a link reference is an inline link or an embed.
enum LinkKind { link, embed }

/// The syntax used for the link (wikilink or standard markdown).
enum LinkSyntax { wiki, markdown }

/// Record of a link or embed in the vault.
final class LinkRecord {
  const LinkRecord({
    required this.source,
    required this.targetRaw,
    this.targetPath,
    required this.kind,
    required this.syntax,
    this.heading,
    this.blockRef,
    this.alias,
    this.embedSize,
    required this.start,
    required this.end,
    required this.line,
    required this.resolved,
    required this.viaAlias,
  });

  final VaultPath source;
  final String targetRaw;
  final VaultPath? targetPath;
  final LinkKind kind;
  final LinkSyntax syntax;
  final String? heading;
  final String? blockRef;
  final String? alias;
  final String? embedSize;
  final int start;
  final int end;
  final int line;
  final bool resolved;
  final bool viaAlias;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkRecord &&
          source == other.source &&
          targetRaw == other.targetRaw &&
          targetPath == other.targetPath &&
          kind == other.kind &&
          syntax == other.syntax &&
          heading == other.heading &&
          blockRef == other.blockRef &&
          alias == other.alias &&
          embedSize == other.embedSize &&
          start == other.start &&
          end == other.end &&
          line == other.line &&
          resolved == other.resolved &&
          viaAlias == other.viaAlias;

  @override
  int get hashCode => Object.hash(
    source,
    targetRaw,
    targetPath,
    kind,
    syntax,
    heading,
    blockRef,
    alias,
    embedSize,
    start,
    end,
    line,
    resolved,
    viaAlias,
  );

  @override
  String toString() =>
      'LinkRecord(source: ${source.value}, targetRaw: $targetRaw, resolved: $resolved)';
}
