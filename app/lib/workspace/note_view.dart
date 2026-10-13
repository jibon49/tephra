// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../l10n/app_localizations.dart';
import '../reading/reading_controller.dart';
import '../reading/reading_view.dart';
import '../vault/note_document.dart';
import '../vault/providers.dart';
import 'providers.dart';

class NoteView extends ConsumerWidget {
  const NoteView({
    required this.path,
    this.subpath,
    required this.tabId,
    super.key,
  });

  final VaultPath path;
  final String? subpath;
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final doc = ref.watch(noteDocumentProvider(path));

    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        if (!doc.isLoaded) {
          if (doc.saveState == SaveState.error) {
            return Center(
              child: Text(
                'Error loading note: ${doc.lastError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.readingLoading),
              ],
            ),
          );
        }

        if (doc.isMissing) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.noteMissing),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.read(workspaceProvider.notifier).closeTabById(tabId);
                  },
                  child: Text(l10n.tabClose),
                ),
              ],
            ),
          );
        }

        return NoteReadingView(path: path, tabId: tabId, doc: doc);
      },
    );
  }
}

class NoteReadingView extends StatefulWidget {
  const NoteReadingView({
    super.key,
    required this.path,
    required this.tabId,
    required this.doc,
  });

  final VaultPath path;
  final String tabId;
  final NoteDocument doc;

  @override
  State<NoteReadingView> createState() => _NoteReadingViewState();
}

class _NoteReadingViewState extends State<NoteReadingView> {
  final ReadingViewController _controller = ReadingViewController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.doc.isReadOnly)
          Container(
            key: const ValueKey('note.malformedBanner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
            ),
            child: Text(
              l10n.noteMalformedBanner,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: ReadingView(
            path: widget.path,
            text: widget.doc.text,
            readOnly: widget.doc.isReadOnly,
            controller: _controller,
          ),
        ),
      ],
    );
  }
}
