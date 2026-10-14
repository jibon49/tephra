// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../core/providers.dart';
import '../editor/edit_operation.dart';
import '../editor/editor_controller.dart';
import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'outline_tree.dart';
import 'providers.dart';
import 'section_mover.dart';

/// Outline sidebar panel displaying heading hierarchy for the active note.
class OutlinePane extends ConsumerStatefulWidget {
  const OutlinePane({super.key});

  @override
  ConsumerState<OutlinePane> createState() => _OutlinePaneState();
}

class _OutlinePaneState extends ConsumerState<OutlinePane> {
  final Set<int> _collapsedHeadingIndices = {};
  int _caretOffset = -1;
  StreamSubscription<void>? _selectionSub;
  EditorController? _subscribedEditor;

  @override
  void dispose() {
    _selectionSub?.cancel();
    super.dispose();
  }

  void _syncEditorSubscription(EditorController? editor) {
    if (editor == _subscribedEditor) return;
    _selectionSub?.cancel();
    _subscribedEditor = editor;
    if (editor != null) {
      _caretOffset = editor.selection.baseOffset;
      _selectionSub = editor.selectionChanges.listen((_) {
        if (mounted) {
          final newOffset = editor.selection.baseOffset;
          if (newOffset != _caretOffset) {
            setState(() {
              _caretOffset = newOffset;
            });
          }
        }
      });
    } else {
      _caretOffset = -1;
    }
  }

  int _findActiveHeadingIndex(
    List<MdHeading> headings,
    int caretOffset,
    int textLength,
  ) {
    if (caretOffset < 0 || headings.isEmpty) return -1;
    var activeIdx = -1;
    for (var i = 0; i < headings.length; i++) {
      final (s, e) = sectionOf(headings, i, textLength);
      if (caretOffset >= s &&
          (caretOffset < e || (e == textLength && caretOffset == textLength))) {
        activeIdx = i;
      }
    }
    return activeIdx;
  }

  void _flattenVisibleNodes(List<OutlineNode> nodes, List<OutlineNode> output) {
    for (final node in nodes) {
      output.add(node);
      if (!_collapsedHeadingIndices.contains(node.headingIndex) &&
          node.children.isNotEmpty) {
        _flattenVisibleNodes(node.children, output);
      }
    }
  }

  void _toggleCollapsed(int headingIndex) {
    setState(() {
      if (_collapsedHeadingIndices.contains(headingIndex)) {
        _collapsedHeadingIndices.remove(headingIndex);
      } else {
        _collapsedHeadingIndices.add(headingIndex);
      }
    });
  }

  void _jumpToHeading(OutlineNode node, VaultPath? activePath) {
    final editor = ref.read(activeEditorProvider);
    if (editor != null) {
      editor.select(node.heading.start);
      editor.revealOffset(node.heading.start);
    } else {
      final readingCtrl = ref.read(activeReadingControllerProvider);
      if (readingCtrl != null) {
        readingCtrl.scrollToOffset(node.heading.start);
      } else if (activePath != null) {
        ref
            .read(pendingJumpProvider.notifier)
            .set(PendingJump(path: activePath, offset: node.heading.start));
      }
    }
  }

  void _applyMoveEdits(
    List<TextEdit> edits,
    String currentText,
    VaultPath? activePath,
  ) {
    final controller = ref.read(activeEditorProvider);
    if (controller != null) {
      controller.applyEdits(
        edits.map((e) => EditOperation(e.start, e.end, e.replacement)).toList(),
      );
    } else if (activePath != null) {
      final doc = ref.read(noteDocumentProvider(activePath));
      final newText = applyTextEdits(currentText, edits);
      doc.setText(newText);
    }
  }

  Future<void> _showPhoneHeadingMenu(
    BuildContext context,
    OutlineNode node,
    VaultPath activePath,
  ) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(vaultSettingsProvider);
    LinkTargetLookup lookup = NameTable();
    try {
      final index = await ref.read(noteIndexProvider.future);
      lookup = await index.loadNameTable();
    } catch (_) {}

    final linkFormatter = LinkFormatter(
      lookup,
      LinkFormatSettings(
        format: settings.newLinkFormatEnum,
        useMarkdownLinks: false,
      ),
    );
    final link = linkFormatter.buildLink(
      activePath,
      from: activePath,
      heading: node.text,
    );

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.copyLinkToHeading),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.headingLinkCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(l10n.bookmarkHeading),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.headingBookmarked),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropGap({
    required BuildContext context,
    required int insertAt,
    required String text,
    required List<MdHeading> headings,
    required VaultPath? activePath,
  }) {
    return DragTarget<int>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        final draggedIdx = details.data;
        final edits = moveSectionEdits(text, headings, draggedIdx, insertAt);
        return edits != null;
      },
      onAcceptWithDetails: (details) {
        final draggedIdx = details.data;
        final edits = moveSectionEdits(text, headings, draggedIdx, insertAt);
        if (edits != null) {
          _applyMoveEdits(edits, text, activePath);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered =
            candidateData.isNotEmpty && candidateData.first != null;
        final canAccept =
            isHovered &&
            moveSectionEdits(text, headings, candidateData.first!, insertAt) !=
                null;

        final colorScheme = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered && canAccept ? 6 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isHovered && canAccept
                ? colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final activePath = ref.watch(activeNotePathProvider);
    final editor = ref.watch(activeEditorProvider);
    _syncEditorSubscription(editor);

    if (activePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.noActiveNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final parsed = ref.watch(activeParsedNoteProvider);
    final tree = ref.watch(outlineTreeProvider);

    if (parsed == null || tree.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.outlineNoHeadings,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final headings = parsed.headings;
    final currentText =
        editor?.text ?? ref.watch(noteDocumentProvider(activePath)).text;
    final activeIdx = _findActiveHeadingIndex(
      headings,
      _caretOffset,
      currentText.length,
    );

    final visibleNodes = <OutlineNode>[];
    _flattenVisibleNodes(tree, visibleNodes);

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sidebarOutline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _collapsedHeadingIndices.isEmpty
                      ? Icons.unfold_less
                      : Icons.unfold_more,
                  size: 20,
                ),
                tooltip: l10n.collapseAllAction,
                onPressed: () {
                  setState(() {
                    if (_collapsedHeadingIndices.isEmpty) {
                      _collapsedHeadingIndices.addAll(headings.asMap().keys);
                    } else {
                      _collapsedHeadingIndices.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: visibleNodes.length * 2 + 1,
            itemBuilder: (context, index) {
              if (index.isEven) {
                // Drop target gap above visible row (index ~/ 2) or at the end
                final gapIndex = index ~/ 2;
                if (!isDesktop) return const SizedBox(height: 2);
                final insertAt = gapIndex < visibleNodes.length
                    ? visibleNodes[gapIndex].heading.start
                    : currentText.length;
                return _buildDropGap(
                  context: context,
                  insertAt: insertAt,
                  text: currentText,
                  headings: headings,
                  activePath: activePath,
                );
              }

              final nodeIndex = index ~/ 2;
              final node = visibleNodes[nodeIndex];
              final isCaretActive = node.headingIndex == activeIdx;

              final rowWidget = Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: isCaretActive
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _jumpToHeading(node, activePath),
                  onLongPress: isDesktop
                      ? null
                      : () => _showPhoneHeadingMenu(context, node, activePath),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 4.0 + 16.0 * node.depth,
                      right: 8.0,
                      top: 4.0,
                      bottom: 4.0,
                    ),
                    child: Row(
                      children: [
                        if (node.children.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggleCollapsed(node.headingIndex),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(
                                _collapsedHeadingIndices.contains(
                                      node.headingIndex,
                                    )
                                    ? Icons.chevron_right
                                    : Icons.expand_more,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 22),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            node.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isCaretActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (isDesktop) {
                return Draggable<int>(
                  data: node.headingIndex,
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(node.text, style: theme.textTheme.bodyMedium),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: rowWidget),
                  child: rowWidget,
                );
              }

              return rowWidget;
            },
          ),
        ),
      ],
    );
  }
}
