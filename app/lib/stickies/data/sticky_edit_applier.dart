// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../windows/text_merger.dart';
import 'open_note_bridge.dart';
import 'sticky_repository.dart';

/// Function signature for creating collision-safe conflict file paths.
typedef ConflictCopyNamer = VaultPath Function(VaultPath path);

/// Computes the protocol SHA-256 hash on '\n'-normalized text.
String hashProtocolText(String text) {
  return contentHash(utf8.encode(text.replaceAll('\r\n', '\n')));
}

/// Result of applying an incoming edit through [StickyEditApplier].
final class AppliedEditResult {
  const AppliedEditResult({
    required this.text,
    required this.hash,
    required this.isConflict,
  });

  /// The final text after applying the edit (or merge).
  final String text;

  /// The protocol hash of [text].
  final String hash;

  /// Whether a conflict occurred requiring a conflict-copy file to be written.
  final bool isConflict;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppliedEditResult &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          hash == other.hash &&
          isConflict == other.isConflict;

  @override
  int get hashCode => text.hashCode ^ hash.hashCode ^ isConflict.hashCode;

  @override
  String toString() =>
      'AppliedEditResult(text: ${text.length} chars, hash: $hash, isConflict: $isConflict)';
}

/// Applies content edits from secondary windows or floating overlays to the sticky repository.
///
/// Implements three-way text merging against known base versions, or creates conflict copies
/// if a merge produces conflicts or if the base version is unknown.
final class StickyEditApplier {
  StickyEditApplier({
    required this.repo,
    required this.openNotes,
    required this.merger,
    required this.conflictNamer,
  });

  final StickyRepository repo;
  final OpenNoteBridge openNotes;
  final TextMerger merger;
  final ConflictCopyNamer conflictNamer;

  /// Applies incoming [text] based on [baseHash] against the current note at [path].
  ///
  /// [baseTextLookup] provides previous sent text versions for [baseHash].
  Future<AppliedEditResult> applyEdit({
    required VaultPath path,
    required String text,
    required String baseHash,
    String? Function(String hash)? baseTextLookup,
  }) async {
    final current =
        openNotes.openText(path) ??
        (repo.byPath(path)?.text ??
            (await repo.fs.stat(path) != null
                ? (await repo.fs.readText(path)).text
                : ''));
    final currentHash = hashProtocolText(current);

    var isConflict = false;

    if (currentHash == baseHash) {
      await repo.setText(path, text);
    } else {
      final baseText = baseTextLookup?.call(baseHash);
      if (baseText != null) {
        final outcome = merger.merge(
          base: baseText,
          local: text,
          remote: current,
        );

        if (outcome is MergeClean) {
          await repo.setText(path, outcome.text);
        } else {
          isConflict = true;
          final conflictPath = conflictNamer(path);
          await repo.fs.writeText(conflictPath, TextDocument(text: current));
          await repo.setText(path, text);
        }
      } else {
        isConflict = true;
        final conflictPath = conflictNamer(path);
        await repo.fs.writeText(conflictPath, TextDocument(text: current));
        await repo.setText(path, text);
      }
    }

    final finalText =
        openNotes.openText(path) ?? (repo.byPath(path)?.text ?? text);
    final finalHash = hashProtocolText(finalText);
    return AppliedEditResult(
      text: finalText,
      hash: finalHash,
      isConflict: isConflict,
    );
  }
}
