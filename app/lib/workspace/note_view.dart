// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../reading/link_actions.dart';
import '../reading/reading_controller.dart';
import '../reading/reading_view.dart';
import '../reading/task_toggler.dart';
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

        return NoteReadingView(
          path: path,
          subpath: subpath,
          tabId: tabId,
          doc: doc,
        );
      },
    );
  }
}

class NoteReadingView extends ConsumerStatefulWidget {
  const NoteReadingView({
    super.key,
    required this.path,
    this.subpath,
    required this.tabId,
    required this.doc,
  });

  final VaultPath path;
  final String? subpath;
  final String tabId;
  final NoteDocument doc;

  @override
  ConsumerState<NoteReadingView> createState() => _NoteReadingViewState();
}

class _NoteReadingViewState extends ConsumerState<NoteReadingView> {
  final ReadingViewController _controller = ReadingViewController();
  final TaskToggler _taskToggler = const TaskToggler();

  @override
  void initState() {
    super.initState();
    _checkPendingJump();
  }

  @override
  void didUpdateWidget(NoteReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path || widget.subpath != oldWidget.subpath) {
      _checkPendingJump();
    }
  }

  void _checkPendingJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final jump = ref.read(pendingJumpProvider.notifier).consume(widget.path);
      if (jump != null) {
        if (jump.heading != null) {
          _controller.scrollToHeading(jump.heading!);
        } else if (jump.blockRef != null) {
          _controller.scrollToBlockRef(jump.blockRef!);
        }
      } else if (widget.subpath != null) {
        if (widget.subpath!.startsWith('#^')) {
          _controller.scrollToBlockRef(widget.subpath!.substring(2));
        } else if (widget.subpath!.startsWith('#')) {
          _controller.scrollToHeading(widget.subpath!.substring(1));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linkActions = LinkActions(
      ref: ref,
      context: context,
      from: widget.path,
      controller: _controller,
    );

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
            onToggleTask: (task, newStatus) =>
                _taskToggler.toggleTask(widget.doc, task, newStatus),
            onOpenWikiLink: linkActions.openWikiLink,
            onOpenMarkdownLink: linkActions.openMarkdownLink,
            onOpenUrl: (uri) =>
                launchUrl(uri, mode: LaunchMode.externalApplication),
          ),
        ),
      ],
    );
  }
}
