// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../links/providers.dart';
import 'block_lookup.dart';
import 'providers.dart';
import 'reading_blocks.dart';
import 'reading_controller.dart';
import 'reading_footnotes.dart';
import 'reading_scope.dart';
import 'reading_styles.dart';

/// Pure reading view rendering Markdown blocks with scrolling and selection.
class ReadingView extends ConsumerStatefulWidget {
  const ReadingView({
    super.key,
    required this.path,
    required this.text,
    this.controller,
    this.readOnly = false,
    this.readableWidth = true,
    this.onToggleTask,
    this.onOpenWikiLink,
    this.onOpenMarkdownLink,
    this.onOpenUrl,
    this.initialOffset,
    this.onTopOffsetChanged,
  });

  final VaultPath path;
  final String text;
  final ReadingViewController? controller;
  final bool readOnly;
  final bool readableWidth;
  final Future<void> Function(TaskItem task, String newStatus)? onToggleTask;
  final void Function(WikiLinkTap tap)? onOpenWikiLink;
  final void Function(String url, {bool newTab})? onOpenMarkdownLink;
  final void Function(Uri uri)? onOpenUrl;
  final int? initialOffset;
  final void Function(int sourceOffset)? onTopOffsetChanged;

  @override
  ConsumerState<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends ConsumerState<ReadingView>
    implements ReadingViewStateAccessor {
  ParsedNote? _parsed;
  String? _parsedText;
  FootnoteIndex? _footnoteIndex;
  List<MdNode> _visibleBlocks = const [];
  final Set<int> _toggledCallouts = {};

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  Timer? _spinnerTimer;
  bool _showSpinner = false;
  Timer? _throttleTimer;
  int? _topOffset;

  @override
  int? get topOffset => _topOffset;

  @override
  ParsedNote? get parsed => _parsed;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    _startParse(widget.text);
  }

  @override
  void didUpdateWidget(ReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (widget.text != oldWidget.text) {
      _startParse(widget.text);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _spinnerTimer?.cancel();
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _startParse(String textToParse) {
    if (textToParse == _parsedText && _parsed != null) return;

    if (_parsed == null) {
      _spinnerTimer?.cancel();
      _spinnerTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && _parsed == null) {
          setState(() {
            _showSpinner = true;
          });
        }
      });
    }

    ref.read(parseServiceProvider).parse(textToParse).then((result) {
      if (!mounted) return;
      if (widget.text != textToParse) return; // Stale parse

      _spinnerTimer?.cancel();
      final footnotes = buildFootnoteIndex(result);
      final visible = _filterVisibleBlocks(result.root.children);

      setState(() {
        _parsed = result;
        _parsedText = textToParse;
        _footnoteIndex = footnotes;
        _visibleBlocks = visible;
        _showSpinner = false;
      });

      if (widget.initialOffset != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.initialOffset != null) {
            scrollToOffset(widget.initialOffset!);
          }
        });
      }
    });
  }

  List<MdNode> _filterVisibleBlocks(List<MdNode> children) {
    return children.where((node) {
      if (node is MdFrontmatter ||
          node is MdCommentBlock ||
          node is MdFootnoteDefinition) {
        return false;
      }
      if (node is MdHtmlBlock && isCommentOnlyHtml(node.html)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onPositionsChanged() {
    if (widget.onTopOffsetChanged == null) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    int minIndex = positions.first.index;
    for (final p in positions) {
      if (p.index < minIndex) {
        minIndex = p.index;
      }
    }

    if (minIndex >= 0 && minIndex < _visibleBlocks.length) {
      final offset = _visibleBlocks[minIndex].start;
      _topOffset = offset;
      if (_throttleTimer?.isActive ?? false) return;
      _throttleTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted && _topOffset != null) {
          widget.onTopOffsetChanged?.call(_topOffset!);
        }
      });
    }
  }

  @override
  void scrollToOffset(int offset) {
    if (_visibleBlocks.isEmpty) return;
    final index = blockIndexForOffset(_visibleBlocks, offset);
    if (index >= 0 && index < _visibleBlocks.length) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: index);
      }
    }
  }

  @override
  void scrollToHeading(String heading) {
    if (_parsed == null) return;
    final normQuery = _normalizeHeading(heading);
    for (final h in _parsed!.headings) {
      final normHeading = _normalizeHeading(_extractNodeText(h));
      if (normHeading == normQuery) {
        scrollToOffset(h.start);
        return;
      }
    }
  }

  @override
  void scrollToBlockRef(String id) {
    if (_parsed == null) return;
    final lower = id.toLowerCase();
    for (final ref in _parsed!.blockIds) {
      if (ref.id.toLowerCase() == lower) {
        scrollToOffset(ref.start);
        return;
      }
    }
  }

  String _normalizeHeading(String text) {
    return text
        .replaceAll(RegExp(r'[\[\]|#^\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _extractNodeText(MdNode node) {
    if (node is MdText) return node.text;
    if (node is MdInlineCode) return node.code;
    if (node is MdInlineMath) return node.tex;
    if (node.children.isNotEmpty) {
      return node.children.map(_extractNodeText).join();
    }
    return '';
  }

  void _onToggleCallout(int startOffset) {
    setState(() {
      if (_toggledCallouts.contains(startOffset)) {
        _toggledCallouts.remove(startOffset);
      } else {
        _toggledCallouts.add(startOffset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_parsed == null) {
      if (_showSpinner) {
        return const Center(child: CircularProgressIndicator());
      }
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16.0;
    final styles = ReadingStyles.of(theme, fontSize);

    final hasFootnotes = _footnoteIndex?.hasReferences ?? false;
    final totalItems = _visibleBlocks.length + (hasFootnotes ? 1 : 0);

    final unresolvedTargets = <String>{};
    final seen = <String>{};
    for (final w in _parsed!.wikiLinks) {
      if (w.target.isNotEmpty && seen.add(w.target)) {
        final res = ref.watch(linkResolutionProvider((widget.path, w.target)));
        if (res.hasValue && res.value == null) {
          unresolvedTargets.add(w.target);
        }
      }
    }
    for (final l in _parsed!.links) {
      if (l.url.isNotEmpty && Uri.tryParse(l.url)?.hasScheme != true) {
        final pathPart = LinkFormatter.decodeMarkdownPath(
          l.url.split('#').first,
        );
        if (pathPart.isNotEmpty && seen.add(pathPart)) {
          final res = ref.watch(
            linkResolutionProvider((widget.path, pathPart)),
          );
          if (res.hasValue && res.value == null) {
            unresolvedTargets.add(pathPart);
          }
        }
      }
    }

    return ReadingScope(
      path: widget.path,
      parsed: _parsed!,
      text: widget.text,
      styles: styles,
      footnoteNumbers: _footnoteIndex?.numbers ?? const {},
      readOnly: widget.readOnly,
      toggledCallouts: _toggledCallouts,
      unresolvedLinks: unresolvedTargets,
      onToggleCallout: _onToggleCallout,
      onToggleTask: widget.onToggleTask,
      onOpenWikiLink: widget.onOpenWikiLink,
      onOpenMarkdownLink: widget.onOpenMarkdownLink,
      onOpenUrl: widget.onOpenUrl,
      controller: widget.controller,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final h = width < 600 ? 16.0 : 32.0;
          final shouldConstrain = widget.readableWidth && width > 760;

          return SelectionArea(
            child: ScrollablePositionedList.builder(
              itemCount: totalItems,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: EdgeInsets.fromLTRB(h, 16, h, 96),
              itemBuilder: (context, index) {
                final Widget item;
                if (index < _visibleBlocks.length) {
                  item = buildBlock(context, _visibleBlocks[index]);
                } else {
                  item = FootnoteSectionView(index: _footnoteIndex!);
                }

                if (shouldConstrain) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: item,
                    ),
                  );
                }

                return item;
              },
            ),
          );
        },
      ),
    );
  }
}
