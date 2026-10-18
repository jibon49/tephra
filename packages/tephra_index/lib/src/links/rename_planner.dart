// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../extract/note_extractor.dart';
import '../model/link_record.dart';
import '../model/model_helpers.dart';
import 'link_format_settings.dart';
import 'link_formatter.dart';
import 'link_resolver.dart';
import 'link_span_locator.dart';
import 'name_table.dart';
import 'text_edit.dart';

/// The calculated plan for updating links across the vault during a rename/move operation.
final class RenamePlan {
  const RenamePlan(this.moves, this.fileEdits);

  final Map<VaultPath, VaultPath> moves;
  final List<FileEdit> fileEdits;

  int get linkCount => fileEdits.fold(0, (sum, e) => sum + e.edits.length);
  int get fileCount => fileEdits.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenamePlan &&
          runtimeType == other.runtimeType &&
          mapEquals(moves, other.moves) &&
          listEquals(fileEdits, other.fileEdits);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(moves.entries), Object.hashAll(fileEdits));

  @override
  String toString() =>
      'RenamePlan(moves: $moves, fileEdits: $fileEdits, links: $linkCount, files: $fileCount)';
}

/// Computes text edits needed across notes when files are renamed or moved.
final class RenamePlanner {
  RenamePlanner({required this.before, required this.settings});

  final NameTable before;
  final LinkFormatSettings settings;

  /// [moves]: every moved file old -> new (a folder move lists every file inside it).
  /// [sources]: current text of every note to inspect (old path -> text).
  RenamePlan plan(
    Map<VaultPath, VaultPath> moves,
    Map<VaultPath, String> sources,
  ) {
    final after = before.copy();
    for (final entry in moves.entries) {
      final old = entry.key;
      final n = entry.value;
      final aliases = before.aliasesOf(old);
      after.removeFile(old);
      after.addFile(n);
      after.setAliases(n, aliases);
    }

    final rBefore = LinkResolver(before);
    final rAfter = LinkResolver(after);
    final fmt = LinkFormatter(after, settings);

    final fileEdits = <FileEdit>[];

    for (final entry in sources.entries) {
      final srcOld = entry.key;
      final text = entry.value;
      final srcNew = moves[srcOld] ?? srcOld;
      final parsed = MarkdownParser.parse(text);
      final links = NoteExtractor.extractLinks(srcOld, parsed);
      final edits = <TextEdit>[];

      for (final L in links) {
        if (L.targetRaw.trim().isEmpty) continue; // [[#Heading]] same-note

        final b = rBefore.resolve(L.targetRaw, from: srcOld);
        if (b == null || b.viaAlias) {
          continue; // unresolved or alias links never change
        }

        final tgtNew = moves[b.path] ?? b.path;
        if (!moves.containsKey(b.path) && !moves.containsKey(srcOld)) continue;

        final a = rAfter.resolve(L.targetRaw, from: srcNew);
        if (a != null && !a.viaAlias && a.path == tgtNew) {
          // The user's text still points to the right file -> keep it
          continue;
        }

        final (s, e, angle) = locateLinkPathSpan(text, L);
        final String newPath;
        if (angle) {
          final raw = fmt.linkPath(
            tgtNew,
            from: srcNew,
            syntax: LinkSyntax.markdown,
          );
          newPath = LinkFormatter.decodeMarkdownPath(raw);
        } else {
          newPath = fmt.linkPath(tgtNew, from: srcNew, syntax: L.syntax);
        }
        edits.add(TextEdit(s, e, newPath));
      }

      if (edits.isNotEmpty) {
        fileEdits.add(FileEdit(srcOld, edits));
      }
    }

    return RenamePlan(moves, fileEdits);
  }
}
