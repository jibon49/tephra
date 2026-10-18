// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

import '../commands/command_registry.dart';
import '../commands/tephra_command.dart';
import '../core/providers.dart';
import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../search/providers.dart';
import '../workspace/providers.dart';
import 'bookmark.dart';
import 'bookmarks_pane.dart';
import 'providers.dart';

Bookmark? _findFileBookmark(
  List<Bookmark> items,
  VaultPath path,
  String? subpath,
) {
  for (final item in items) {
    if (item is FileBookmark && item.path == path && item.subpath == subpath) {
      return item;
    }
    if (item is GroupBookmark) {
      final found = _findFileBookmark(item.items, path, subpath);
      if (found != null) return found;
    }
  }
  return null;
}

/// Registers commands related to bookmarks.
void registerBookmarkCommands(CommandRegistry registry) {
  registry.register(
    TephraCommand(
      id: 'bookmarks.toggle-current-file',
      label: (l10n) => l10n.bookmarkCurrentFile,
      icon: Icons.bookmark_outline,
      run: (ref, context) async {
        final path = ref.read(activeNotePathProvider);
        if (path == null) return;

        final isBookmarked = ref
            .read(bookmarksProvider.notifier)
            .isBookmarked(path);
        final l10n = AppLocalizations.of(context);
        if (isBookmarked) {
          final bookmarks = ref.read(bookmarksProvider).value ?? const [];
          final b = _findFileBookmark(bookmarks, path, null);
          if (b != null) {
            await ref.read(bookmarksProvider.notifier).remove(b);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.bookmarkFileRemoved)));
            }
          }
        } else {
          final newBookmark = FileBookmark(
            path: path,
            ctime: DateTime.now().millisecondsSinceEpoch,
          );
          await ref.read(bookmarksProvider.notifier).add(newBookmark);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.bookmarkFileAdded)));
          }
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'bookmarks.add-heading',
      label: (l10n) => l10n.commandBookmarkHeading,
      icon: Icons.tag,
      run: (ref, context) async {
        final path = ref.read(activeNotePathProvider);
        if (path == null) return;

        final editor = ref.read(activeEditorProvider);
        final l10n = AppLocalizations.of(context);
        if (editor != null && editor.path == path) {
          final index = await ref.read(noteIndexProvider.future);
          final headings = await index.headings(path);
          final caret = editor.selection.baseOffset;
          HeadingRecord? targetHeading;
          for (final h in headings) {
            if (h.start <= caret && h.end >= caret) {
              targetHeading = h;
              break;
            }
          }
          targetHeading ??= headings.isNotEmpty ? headings.first : null;
          if (targetHeading != null) {
            final b = FileBookmark(
              path: path,
              subpath: '#${targetHeading.text}',
              ctime: DateTime.now().millisecondsSinceEpoch,
            );
            await ref.read(bookmarksProvider.notifier).add(b);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.headingBookmarked)));
            }
          }
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'bookmarks.add-search',
      label: (l10n) => l10n.commandBookmarkSearch,
      icon: Icons.search,
      run: (ref, context) async {
        final query = ref.read(searchControllerProvider).query.trim();
        if (query.isEmpty) return;
        final b = SearchBookmark(
          query: query,
          ctime: DateTime.now().millisecondsSinceEpoch,
        );
        await ref.read(bookmarksProvider.notifier).add(b);
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.bookmarkSearchAdded)));
        }
      },
    ),
  );

  registry.register(
    TephraCommand(
      id: 'bookmarks.new-group',
      label: (l10n) => l10n.commandBookmarkNewGroup,
      icon: Icons.create_new_folder_outlined,
      run: (ref, context) async {
        final title = await showBookmarkGroupDialog(context);
        if (title != null && title.trim().isNotEmpty) {
          final group = GroupBookmark(
            title: title.trim(),
            ctime: DateTime.now().millisecondsSinceEpoch,
            items: [],
          );
          await ref.read(bookmarksProvider.notifier).add(group);
        }
      },
    ),
  );
}
