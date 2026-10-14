// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../vault/note_document.dart';

/// Shows a non-dismissible dialog allowing the user to resolve an external edit conflict.
Future<void> showConflictDialog(BuildContext context, NoteDocument doc) async {
  final l10n = AppLocalizations.of(context);
  final fileName = doc.path.name.isNotEmpty ? doc.path.name : doc.path.value;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.conflictTitle(fileName)),
          content: Text(l10n.conflictBody),
          actions: [
            TextButton(
              key: const Key('conflict.mine'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await doc.resolveConflict(ConflictChoice.keepMine);
              },
              child: Text(l10n.conflictKeepMine),
            ),
            TextButton(
              key: const Key('conflict.theirs'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await doc.resolveConflict(ConflictChoice.takeTheirs);
              },
              child: Text(l10n.conflictTakeTheirs),
            ),
            FilledButton(
              key: const Key('conflict.both'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await doc.resolveConflict(ConflictChoice.keepBoth);
              },
              child: Text(l10n.conflictKeepBoth),
            ),
          ],
        ),
      );
    },
  );
}
