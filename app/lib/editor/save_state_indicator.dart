// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../vault/note_document.dart';

/// Small row widget displaying the current [SaveState] of a [NoteDocument].
class SaveStateIndicator extends StatelessWidget {
  const SaveStateIndicator({super.key, required this.doc});

  final NoteDocument doc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);

        Widget icon;
        String text;
        Color? textColor;
        VoidCallback? onTap;

        switch (doc.saveState) {
          case SaveState.saved:
            icon = Icon(
              Icons.check_circle_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            );
            text = l10n.saveStateSaved;
            textColor = theme.colorScheme.onSurfaceVariant;
          case SaveState.unsaved:
            icon = Icon(
              Icons.edit_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            );
            text = l10n.saveStateUnsaved;
            textColor = theme.colorScheme.onSurfaceVariant;
          case SaveState.saving:
            icon = const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
            text = l10n.saveStateSaving;
            textColor = theme.colorScheme.onSurfaceVariant;
          case SaveState.error:
            icon = Icon(
              Icons.error_outline,
              size: 14,
              color: theme.colorScheme.error,
            );
            text = l10n.saveStateError;
            textColor = theme.colorScheme.error;
            onTap = () {
              doc.save();
            };
        }

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
        );

        if (onTap != null) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}
