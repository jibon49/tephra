// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import 'package:url_launcher/url_launcher.dart';

import '../editor/source_editor_view.dart';
import '../l10n/app_localizations.dart';
import '../reading/link_actions.dart';
import '../reading/reading_controller.dart';
import '../reading/reading_view.dart';
import '../reading/task_toggler.dart';
import '../vault/note_document.dart';
import '../vault/providers.dart';
import 'providers.dart';
import 'workspace_models.dart';

class NoteView extends ConsumerStatefulWidget {
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
  ConsumerState<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends ConsumerState<NoteView> {
  int? _lastOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final doc = ref.watch(noteDocumentProvider(widget.path));

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
                    ref
                        .read(workspaceProvider.notifier)
                        .closeTabById(widget.tabId);
                  },
                  child: Text(l10n.tabClose),
                ),
              ],
            ),
          );
        }

        final ws = ref.watch(workspaceProvider);
        final tab = ws.findTab(widget.tabId);
        final mode = tab?.mode ?? ViewMode.reading;

        if (mode == ViewMode.source) {
          return KeyedSubtree(
            key: ValueKey('${widget.tabId}:${mode.name}'),
            child: SourceEditorView(
              path: widget.path,
              tabId: widget.tabId,
              initialOffset: _lastOffset,
              onOffsetChanged: (offset) {
                _lastOffset = offset;
              },
            ),
          );
        }

        return KeyedSubtree(
          key: ValueKey('${widget.tabId}:${mode.name}'),
          child: NoteReadingView(
            path: widget.path,
            subpath: widget.subpath,
            tabId: widget.tabId,
            doc: doc,
            initialOffset: _lastOffset,
            onOffsetChanged: (offset) {
              _lastOffset = offset;
            },
          ),
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
    this.initialOffset,
    this.onOffsetChanged,
  });

  final VaultPath path;
  final String? subpath;
  final String tabId;
  final NoteDocument doc;
  final int? initialOffset;
  final void Function(int offset)? onOffsetChanged;

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
            initialOffset: widget.initialOffset,
            onTopOffsetChanged: widget.onOffsetChanged,
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
