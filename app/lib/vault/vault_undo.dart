// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../bookmarks/providers.dart';
import '../editor/edit_operation.dart';
import '../editor/providers.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../workspace/providers.dart';
import 'providers.dart';

/// Single file modification recorded as part of a [VaultOperation].
final class FileChange {
  const FileChange({
    required this.path,
    required this.oldText,
    required this.newText,
    required this.inBuffer,
  });

  final VaultPath path;
  final String oldText;
  final String newText;
  final bool inBuffer;
}

/// A multi-file operation (such as rename/link maintenance) that can be undone.
final class VaultOperation {
  VaultOperation({
    required this.moves,
    required this.changes,
    this.folderMove,
    this.oldBookmarksJson,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  /// Map of old path -> new path for all individual files moved.
  final Map<VaultPath, VaultPath> moves;

  /// Text changes made to files (at their paths AFTER the move).
  final List<FileChange> changes;

  /// If this was a top-level folder move, (from, to).
  final (VaultPath from, VaultPath to)? folderMove;

  /// Snapshot of bookmarks JSON before this operation.
  final String? oldBookmarksJson;

  final DateTime at;
}

/// Result of executing an undo operation.
final class UndoResult {
  const UndoResult({required this.restoredFiles, required this.conflicts});

  final int restoredFiles;
  final int conflicts;

  bool get isClean => conflicts == 0;
}

/// Manages an undo stack of recent vault-level operations (max 20 entries).
final class VaultUndoStackNotifier extends Notifier<List<VaultOperation>> {
  @override
  List<VaultOperation> build() => const [];

  void push(VaultOperation op) {
    final list = List<VaultOperation>.from(state);
    list.add(op);
    if (list.length > 20) {
      list.removeAt(0);
    }
    state = list;
  }

  VaultOperation? pop() {
    if (state.isEmpty) return null;
    final list = List<VaultOperation>.from(state);
    final op = list.removeLast();
    state = list;
    return op;
  }

  void clear() {
    state = const [];
  }

  /// Undoes [op] by restoring previous text contents and reversing file/folder moves.
  Future<UndoResult> undo(VaultOperation op) async {
    final fs = ref.read(vaultFsProvider);
    final store = ref.read(noteDocumentStoreProvider);
    final registry = ref.read(editorRegistryProvider);

    var conflicts = 0;
    var restoredFiles = 0;

    // 1. Restore changes in reverse order
    for (final change in op.changes.reversed) {
      final controller = registry.controllerFor(change.path);
      final String currentText;
      TextDocument? doc;

      if (controller != null) {
        currentText = controller.text;
      } else {
        try {
          doc = await fs.readText(change.path);
          currentText = doc.text;
        } catch (_) {
          conflicts++;
          continue;
        }
      }

      if (currentText == change.newText) {
        if (controller != null) {
          controller.applyEdits([
            EditOperation(0, currentText.length, change.oldText),
          ]);
        } else {
          await fs.writeText(
            change.path,
            TextDocument(
              text: change.oldText,
              hasBom: doc!.hasBom,
              lineEnding: doc.lineEnding,
            ),
          );
        }
        restoredFiles++;
      } else {
        conflicts++;
      }
    }

    // 2. Reverse moves
    if (op.folderMove != null) {
      final (from, to) = op.folderMove!;
      // Reversing: move to -> from
      final statTo = await fs.stat(to);
      final statFrom = await fs.stat(from);
      if (statTo == null || (statFrom != null && from.caseKey != to.caseKey)) {
        conflicts++;
      } else {
        try {
          await fs.move(to, from);
          store.retargetPath(to, from);
          ref.read(workspaceProvider.notifier).retargetPath(to, from);
          ref.read(explorerExpandedProvider.notifier).retarget(to, from);
          restoredFiles++;
        } catch (_) {
          conflicts++;
        }
      }
    } else {
      final moveEntries = op.moves.entries.toList().reversed;
      for (final entry in moveEntries) {
        final oldPath = entry.key;
        final newPath = entry.value;
        final statNew = await fs.stat(newPath);
        final statOld = await fs.stat(oldPath);
        if (statNew == null ||
            (statOld != null && oldPath.caseKey != newPath.caseKey)) {
          conflicts++;
        } else {
          try {
            await fs.move(newPath, oldPath);
            store.retargetPath(newPath, oldPath);
            ref.read(workspaceProvider.notifier).retargetPath(newPath, oldPath);
            ref
                .read(explorerExpandedProvider.notifier)
                .retarget(newPath, oldPath);
            restoredFiles++;
          } catch (_) {
            conflicts++;
          }
        }
      }
    }

    if (op.oldBookmarksJson != null) {
      try {
        await ref
            .read(bookmarksProvider.notifier)
            .restoreJson(op.oldBookmarksJson!);
      } catch (_) {
        // Ignore failure restoring bookmarks
      }
    }

    ref.read(vaultRevisionProvider.notifier).bump();

    // 3. Snackbar feedback
    _showFeedback(conflicts);

    return UndoResult(restoredFiles: restoredFiles, conflicts: conflicts);
  }

  /// Undoes the most recent operation on the stack, if any.
  Future<UndoResult?> undoLast() async {
    final op = pop();
    if (op == null) return null;
    return undo(op);
  }

  void _showFeedback(int conflicts) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context == null) return;
      final l10n = AppLocalizations.of(context);
      final message = conflicts == 0
          ? l10n.undoRenameDone
          : l10n.undoRenamePartial(conflicts);

      key.currentState?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
    } catch (_) {
      // Ignore if no UI context
    }
  }
}

/// Provider for vault-level undo operations.
final vaultUndoStackProvider =
    NotifierProvider<VaultUndoStackNotifier, List<VaultOperation>>(
      VaultUndoStackNotifier.new,
    );
