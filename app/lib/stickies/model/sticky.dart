// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'sticky_meta.dart';

/// An in-memory representation of a sticky note.
final class Sticky {
  const Sticky({
    required this.path,
    required this.meta,
    required this.text,
    required this.hash,
    required this.modified,
  });

  /// Vault-relative path of the note file.
  final VaultPath path;

  /// Parsed sticky metadata from the frontmatter.
  final StickyMeta meta;

  /// Full in-memory note text ('\n'-normalized).
  final String text;

  /// Content hash (SHA-256 hex) of the file bytes as read.
  final String hash;

  /// Last modification timestamp on disk.
  final DateTime modified;

  /// Note title derived from file stem.
  String get title => path.stem;

  /// Text body excluding frontmatter delimiters and keys.
  String get body {
    final split = splitFrontmatter(text);
    if (split == null) return text;
    return text.substring(split.bodyStart);
  }

  /// List of deduplicated tags declared in the note.
  List<String> get tags => MarkdownParser.parse(text).tags;

  Sticky copyWith({
    VaultPath? path,
    StickyMeta? meta,
    String? text,
    String? hash,
    DateTime? modified,
  }) {
    return Sticky(
      path: path ?? this.path,
      meta: meta ?? this.meta,
      text: text ?? this.text,
      hash: hash ?? this.hash,
      modified: modified ?? this.modified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sticky &&
          path == other.path &&
          meta == other.meta &&
          text == other.text &&
          hash == other.hash &&
          modified == other.modified;

  @override
  int get hashCode => Object.hash(path, meta, text, hash, modified);

  @override
  String toString() => 'Sticky(path: $path, meta: $meta, hash: $hash)';
}
