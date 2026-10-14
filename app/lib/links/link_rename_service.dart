// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/providers.dart';
import '../editor/edit_operation.dart';
import '../editor/providers.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../vault/vault_undo.dart';
import '../workspace/providers.dart';

/// Outcome of renaming or moving a file or folder and updating referencing links.
final class RenameOutcome {
  const RenameOutcome({
    required this.links,
    required this.files,
    this.undo,
    this.skipped = const [],
  });

  final int links;
  final int files;
  final VaultOperation? undo;
  final List<VaultPath> skipped;
}

typedef RenameConfirmCallback = Future<bool> Function({
  required int links,
  required int files,
});

/// Service orchestrating file/folder rename or move with full link rewriting and undo.
final class LinkRenameService {
  LinkRenameService(this.ref, {this.confirmUpdate});

  final Ref ref;
  final RenameConfirmCallback? confirmUpdate;

  Future<RenameOutcome> renameOrMove(
    VaultPath from,
    VaultPath to, {
    RenameConfirmCallback? onConfirmUpdate,
  }) async {
    final fs = ref.read(vaultFsProvider);
    final statTo = await fs.stat(to);
    if (statTo != null && from.caseKey != to.caseKey) {
      throw FileConflictException(to);
    }

    final statFrom = await fs.stat(from);
    if (statFrom == null) {
      throw FileNotFoundException(from);
    }

    final isFolder = statFrom.isFolder;
    final moves = <VaultPath, VaultPath>{};
    (VaultPath, VaultPath)? folderMove;

    if (isFolder) {
      folderMove = (from, to);
      final entries = await fs.list(folder: from, recursive: true);
      for (final e in entries) {
        if (!e.isFolder) {
          final remainder = e.path.value.substring(from.value.length);
          moves[e.path] = VaultPath('${to.value}$remainder');
        }
      }
    } else {
      moves[from] = to;
    }

    // 3. Find sources: backlinks to each moved file + moved .md notes
    final index = await ref.read(noteIndexProvider.future);
    final sourcePaths = <VaultPath>{};
    for (final m in moves.keys) {
      final backlinks = await index.backlinks(m);
      for (final b in backlinks) {
        sourcePaths.add(b.source);
      }
      if (m.isMarkdown) {
        sourcePaths.add(m);
      }
    }

    // 4. Texts: buffer if open in editor, else read from disk. Guard malformed.
    final registry = ref.read(editorRegistryProvider);
    final texts = <VaultPath, String>{};
    final docMap = <VaultPath, TextDocument>{};
    final skipped = <VaultPath>[];

    for (final p in sourcePaths) {
      final controller = registry.controllerFor(p);
      if (controller != null) {
        texts[p] = controller.text;
      } else {
        try {
          final doc = await fs.readText(p);
          if (doc.malformed) {
            skipped.add(p);
            continue;
          }
          texts[p] = doc.text;
          docMap[p] = doc;
        } catch (_) {
          skipped.add(p);
        }
      }
    }

    // 5. Plan edits
    final table = await index.loadNameTable();
    final vaultSettings = ref.read(vaultSettingsProvider);
    final linkSettings = LinkFormatSettings(
      format: vaultSettings.newLinkFormatEnum,
      useMarkdownLinks: vaultSettings.useMarkdownLinks,
    );

    RenamePlan plan;
    if (texts.length > 50) {
      plan = await Isolate.run(
        () => RenamePlanner(
          before: table,
          settings: linkSettings,
        ).plan(moves, texts),
      );
    } else {
      plan = RenamePlanner(
        before: table,
        settings: linkSettings,
      ).plan(moves, texts);
    }

    // 6. Confirm prompt if alwaysUpdateLinks is false
    var shouldUpdate = true;
    if (!vaultSettings.alwaysUpdateLinks && plan.linkCount > 0) {
      final cb = onConfirmUpdate ?? confirmUpdate;
      if (cb != null) {
        shouldUpdate = await cb(links: plan.linkCount, files: plan.fileCount);
      } else {
        shouldUpdate = await _showConfirmDialog(
          links: plan.linkCount,
          files: plan.fileCount,
        );
      }
    }

    final effectiveEdits = shouldUpdate ? plan.fileEdits : const <FileEdit>[];

    // 7. Flush open notes and move on disk
    final store = ref.read(noteDocumentStoreProvider);
    for (final m in moves.keys) {
      await store.flushPath(m);
    }
    await fs.move(from, to);

    // 8. Apply file edits
    final changes = <FileChange>[];
    for (final fileEdit in effectiveEdits) {
      final newPath = moves[fileEdit.path] ?? fileEdit.path;
      final oldText = texts[fileEdit.path]!;
      final newText = applyTextEdits(oldText, fileEdit.edits);
      if (oldText == newText) continue;

      final controller = registry.controllerFor(fileEdit.path);
      if (controller != null) {
        controller.applyEdits(
          fileEdit.edits
              .map((ed) => EditOperation(ed.start, ed.end, ed.replacement))
              .toList(),
        );
        changes.add(
          FileChange(
            path: newPath,
            oldText: oldText,
            newText: newText,
            inBuffer: true,
          ),
        );
      } else {
        final doc = docMap[fileEdit.path]!;
        await fs.writeText(
          newPath,
          TextDocument(
            text: newText,
            hasBom: doc.hasBom,
            lineEnding: doc.lineEnding,
          ),
        );
        changes.add(
          FileChange(
            path: newPath,
            oldText: oldText,
            newText: newText,
            inBuffer: false,
          ),
        );
      }
    }

    // 9. Retarget open tabs and store
    store.retargetPath(from, to);
    ref.read(workspaceProvider.notifier).retargetPath(from, to);
    ref.read(explorerExpandedProvider.notifier).retarget(from, to);
    ref.read(explorerSelectedProvider.notifier).select(to);
    ref.read(vaultRevisionProvider.notifier).bump();

    // 10. Undo stack and snackbar
    final op = VaultOperation(
      moves: moves,
      changes: changes,
      folderMove: folderMove,
    );
    ref.read(vaultUndoStackProvider.notifier).push(op);

    final updatedLinks = effectiveEdits.fold(
      0,
      (sum, e) => sum + e.edits.length,
    );
    final updatedFiles = effectiveEdits.length;

    if (updatedLinks > 0) {
      _showUpdatedFeedback(updatedLinks, updatedFiles, op);
    }

    return RenameOutcome(
      links: updatedLinks,
      files: updatedFiles,
      undo: op,
      skipped: skipped,
    );
  }

  Future<bool> _showConfirmDialog({
    required int links,
    required int files,
  }) async {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context == null) return true;
      final l10n = AppLocalizations.of(context);
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.renameUpdateLinksTitle),
          content: Text(l10n.renameUpdateLinksPrompt(links, files)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.renameUpdateLinksActionDontUpdate),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.renameUpdateLinksActionUpdate),
            ),
          ],
        ),
      );
      return result ?? false;
    } catch (_) {
      return true;
    }
  }

  void _showUpdatedFeedback(int links, int files, VaultOperation op) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context == null) return;
      final l10n = AppLocalizations.of(context);
      final message = l10n.renameLinksUpdated(links, files);

      key.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () {
              ref.read(vaultUndoStackProvider.notifier).undo(op);
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      // Ignore if no UI context
    }
  }
}

/// Provider for [LinkRenameService].
final linkRenameServiceProvider = Provider<LinkRenameService>((ref) {
  return LinkRenameService(ref);
});
