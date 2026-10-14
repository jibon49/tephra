// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../links/providers.dart';
import '../reading/providers.dart';
import '../reading/reading_view.dart';
import '../search/search_highlights.dart';
import '../vault/note_document.dart';
import '../vault/providers.dart';
import 'attachment_actions.dart';
import 'editor_controller.dart';
import 'editor_drop_target.dart';
import 'engine/re_editor_engine.dart';
import 'find/find_bar.dart';
import 'find/find_controller.dart';
import 'providers.dart';

/// Full Source mode editor widget wrapping [EditorController] and its engine view.
class SourceEditorView extends ConsumerStatefulWidget {
  const SourceEditorView({
    super.key,
    required this.path,
    required this.tabId,
    this.initialOffset,
    this.onOffsetChanged,
  });

  final VaultPath path;
  final String tabId;
  final int? initialOffset;
  final void Function(int offset)? onOffsetChanged;

  @override
  ConsumerState<SourceEditorView> createState() => _SourceEditorViewState();
}

class _SourceEditorViewState extends ConsumerState<SourceEditorView> {
  EditorController? _controller;
  StreamSubscription<void>? _selectionSub;
  StreamSubscription<void>? _editsSub;
  bool _isWaitingForEditor = false;
  bool _isCreatingController = false;
  NoteDocument? _doc;

  @override
  void initState() {
    super.initState();
    _initDocAndEditor();
  }

  void _initDocAndEditor() {
    final doc = ref.read(noteDocumentProvider(widget.path));
    _doc = doc;

    doc.addListener(_onDocChanged);

    if (doc.editor != null && doc.editor != _controller) {
      _isWaitingForEditor = true;
      return;
    }

    if (doc.isLoaded && _controller == null) {
      _isWaitingForEditor = false;
      _createController(doc);
    }
  }

  void _onDocChanged() {
    if (!mounted || _doc == null || _isCreatingController) return;

    if (_doc!.editor != null && _doc!.editor != _controller) {
      if (!_isWaitingForEditor) {
        setState(() {
          _isWaitingForEditor = true;
          _controller?.dispose();
          _controller = null;
        });
      }
      return;
    }

    if (_doc!.editor == null && _doc!.isLoaded && _controller == null) {
      final phase = SchedulerBinding.instance.schedulerPhase;
      final isBuilding = phase == SchedulerPhase.persistentCallbacks;
      if (isBuilding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _doc == null ||
              _controller != null ||
              _doc!.editor != null) {
            return;
          }
          setState(() {
            _isWaitingForEditor = false;
            _createController(_doc!);
          });
        });
      } else {
        setState(() {
          _isWaitingForEditor = false;
          _createController(_doc!);
        });
      }
    }
  }

  void _createController(NoteDocument doc) {
    if (_isCreatingController || _controller != null) return;
    _isCreatingController = true;
    try {
      final baseOptions = ref.read(editorOptionsProvider);
      final options = baseOptions.copyWith(readOnly: doc.isReadOnly);
      final parseService = ref.read(parseServiceProvider);
      final registry = ref.read(editorRegistryProvider);

      final engine = ReEditorEngine(doc.text);
      final controller = EditorController(
        document: doc,
        engine: engine,
        options: options,
        parseService: parseService,
        registry: registry,
      );
      _controller = controller;

      _selectionSub = controller.selectionChanges.listen((_) {
        if (mounted) {
          widget.onOffsetChanged?.call(controller.selection.baseOffset);
        }
      });

      _editsSub = controller.edits.listen((_) {
        clearNoteSearchHighlights(ref, widget.path);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleInitialOffsetAndJumps(controller, doc);
      });
    } finally {
      _isCreatingController = false;
    }
  }

  void _handleInitialOffsetAndJumps(
    EditorController controller,
    NoteDocument doc,
  ) {
    final jump = ref.read(pendingJumpProvider.notifier).consume(widget.path);
    if (jump != null) {
      if (jump.heading != null) {
        final query = jump.heading!.trim().toLowerCase();
        doc.parsed().then((parsedDoc) {
          if (!mounted) return;
          for (final h in parsedDoc.headings) {
            final hText = doc.text
                .substring(h.start, h.end)
                .trim()
                .toLowerCase();
            if (hText.contains(query) || hText.endsWith(query)) {
              controller.select(h.start);
              controller.revealOffset(h.start);
              break;
            }
          }
        });
      } else if (jump.blockRef != null) {
        final query = jump.blockRef!.trim();
        doc.parsed().then((parsedDoc) {
          if (!mounted) return;
          for (final b in parsedDoc.blockIds) {
            if (b.id == query) {
              controller.select(b.start);
              controller.revealOffset(b.start);
              break;
            }
          }
        });
      } else if (jump.offset != null) {
        controller.select(jump.offset!);
        controller.revealOffset(jump.offset!);
      }
    } else if (widget.initialOffset != null) {
      controller.select(widget.initialOffset!);
      controller.revealOffset(widget.initialOffset!);
    }
  }

  @override
  void didUpdateWidget(SourceEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _controller?.dispose();
      _controller = null;
      _selectionSub?.cancel();
      _editsSub?.cancel();
      _doc?.removeListener(_onDocChanged);
      _initDocAndEditor();
    } else {
      _controller?.updateOptions(
        ref
            .read(editorOptionsProvider)
            .copyWith(readOnly: _doc?.isReadOnly ?? false),
      );
    }
  }

  @override
  void dispose() {
    _doc?.removeListener(_onDocChanged);
    _selectionSub?.cancel();
    _editsSub?.cancel();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _handleCtrlClick(PointerUpEvent event) {
    scheduleMicrotask(() {
      if (!mounted || _controller == null) return;
      final offset = _controller!.selection.baseOffset;
      final parsed = _controller!.parsed;
      if (parsed == null) return;

      for (final wiki in parsed.wikiLinks) {
        if (offset >= wiki.start && offset <= wiki.end) {
          ref
              .read(linkNavigatorProvider)
              .open(
                from: widget.path,
                target: wiki.target,
                heading: wiki.heading,
                blockRef: wiki.blockRef,
              );
          return;
        }
      }

      for (final link in parsed.links) {
        if (offset >= link.start && offset <= link.end) {
          final uri = Uri.tryParse(link.url);
          if (uri != null && uri.hasScheme) {
            final scheme = uri.scheme.toLowerCase();
            if (const {'http', 'https', 'mailto', 'tel'}.contains(scheme)) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return;
          }

          final decoded = LinkFormatter.decodeMarkdownPath(link.url);
          final hashIndex = decoded.indexOf('#');
          final String pathPart;
          final String? anchorPart;
          if (hashIndex != -1) {
            pathPart = decoded.substring(0, hashIndex);
            anchorPart = decoded.substring(hashIndex + 1);
          } else {
            pathPart = decoded;
            anchorPart = null;
          }

          String? blockRef;
          String? heading;
          if (anchorPart != null) {
            if (anchorPart.startsWith('^')) {
              blockRef = anchorPart.substring(1);
            } else {
              heading = anchorPart;
            }
          }

          ref
              .read(linkNavigatorProvider)
              .open(
                from: widget.path,
                target: pathPart,
                heading: heading,
                blockRef: blockRef,
              );
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(noteDocumentProvider(widget.path));

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    ref.listen(editorOptionsProvider, (_, next) {
      _controller?.updateOptions(
        next.copyWith(readOnly: _doc?.isReadOnly ?? false),
      );
    });

    if (_isWaitingForEditor && _doc != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('note.openElsewhere'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
            ),
            child: Text(
              l10n.noteOpenElsewhere,
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          Expanded(
            child: ReadingView(
              path: widget.path,
              text: _doc!.text,
              readOnly: true,
            ),
          ),
        ],
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final shouldAutofocus = ref.read(focusEditorOnOpenProvider);
    if (shouldAutofocus) {
      ref.read(focusEditorOnOpenProvider.notifier).set(false);
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final horizontalPadding = isDesktop ? 32.0 : 16.0;

    Widget editorContent = _controller!.buildView(
      context,
      autofocus: shouldAutofocus,
      onPaste: () => handlePasteAttachment(_controller!, ref, context: context),
    );

    editorContent = Listener(
      onPointerUp: (event) {
        if (HardwareKeyboard.instance.isControlPressed) {
          _handleCtrlClick(event);
        }
      },
      child: editorContent,
    );

    if (_controller!.options.readableLineLength && isDesktop) {
      editorContent = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: editorContent,
        ),
      );
    }

    final mainContent = ValueListenableBuilder<FindState>(
      valueListenable: _controller!.findController,
      builder: (context, findState, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (findState.isOpen)
              FindBar(controller: _controller!.findController),
            if (_doc != null && _doc!.isReadOnly)
              Container(
                key: const ValueKey('note.malformedBanner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                ),
                child: Text(
                  l10n.noteMalformedBanner,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: 96,
                ),
                child: editorContent,
              ),
            ),
          ],
        );
      },
    );

    return EditorDropTarget(controller: _controller, child: mainContent);
  }
}
