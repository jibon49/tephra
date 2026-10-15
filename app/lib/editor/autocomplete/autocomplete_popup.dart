// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../editor_controller.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_item.dart';

/// Autocomplete popup widget rendering desktop floating card or phone docked sheet.
class AutocompletePopup extends ConsumerStatefulWidget {
  const AutocompletePopup({
    super.key,
    required this.tabId,
    required this.controller,
    required this.state,
  });

  final String tabId;
  final EditorController controller;
  final AutocompleteState state;

  @override
  ConsumerState<AutocompletePopup> createState() => _AutocompletePopupState();
}

class _AutocompletePopupState extends ConsumerState<AutocompletePopup> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(AutocompletePopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.tabId != oldWidget.tabId) {
      _attach();
    }
    if (widget.state.selected != oldWidget.state.selected) {
      _scrollToSelected();
    }
  }

  void _attach() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(autocompleteControllerProvider(widget.tabId).notifier)
            .attach(widget.controller);
      }
    });
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final rowHeight = isDesktop ? 32.0 : 48.0;
    final targetOffset = widget.state.selected * rowHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    if (targetOffset < currentOffset) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + rowHeight > currentOffset + viewportHeight) {
      _scrollController.jumpTo(targetOffset + rowHeight - viewportHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final items = widget.state.items;
    final selectedIndex = widget.state.selected;
    final notifier = ref.read(
      autocompleteControllerProvider(widget.tabId).notifier,
    );

    final rowHeight = isDesktop ? 32.0 : 48.0;
    final maxVisible = isDesktop ? 8 : 5;
    final visibleCount = math.min(items.length, maxVisible);
    final cardHeight = visibleCount * rowHeight + (isDesktop ? 8.0 : 0.0);

    final listContent = ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 4.0 : 0.0),
      shrinkWrap: true,
      itemCount: items.length,
      itemExtent: rowHeight,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == selectedIndex;

        return _AutocompleteRow(
          item: item,
          isSelected: isSelected,
          isDesktop: isDesktop,
          rowHeight: rowHeight,
          onTap: () => notifier.accept(
            item,
            context: widget.state.context,
            continueIntoSubpath: false,
          ),
          onHover: () => notifier.selectIndex(index),
          onContinue: () => notifier.accept(
            item,
            context: widget.state.context,
            continueIntoSubpath: true,
          ),
        );
      },
    );

    if (isDesktop) {
      final windowSize = MediaQuery.sizeOf(context);
      final cardWidth = math.min(480.0, windowSize.width - 16.0);
      final caretRect = widget.controller.caretRectGlobal();

      final double left;
      final double? top;
      final double? bottom;

      if (caretRect != null) {
        final fitsBelow =
            (windowSize.height - caretRect.bottom) >= (cardHeight + 12.0);
        if (fitsBelow) {
          top = caretRect.bottom + 4.0;
          bottom = null;
        } else {
          top = null;
          bottom = windowSize.height - caretRect.top + 4.0;
        }
        left = caretRect.left.clamp(
          8.0,
          math.max(8.0, windowSize.width - cardWidth - 8.0),
        );
      } else {
        left = 16.0;
        top = 16.0;
        bottom = null;
      }

      return Positioned(
        left: left,
        top: top,
        bottom: bottom,
        width: cardWidth,
        height: cardHeight,
        child: Semantics(
          liveRegion: true,
          label: '${items.length} suggestions',
          child: Material(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: listContent,
          ),
        ),
      );
    } else {
      final viewInsets = MediaQuery.viewInsetsOf(context);
      const keyboardToolbarHeight = 48.0;
      final bottom = viewInsets.bottom + keyboardToolbarHeight;

      return Positioned(
        left: 0,
        right: 0,
        bottom: bottom,
        height: cardHeight,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              notifier.hide();
            }
          },
          child: Semantics(
            liveRegion: true,
            label: '${items.length} suggestions',
            child: Material(
              elevation: 6,
              shape: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              color: theme.colorScheme.surface,
              child: listContent,
            ),
          ),
        ),
      );
    }
  }
}

class _AutocompleteRow extends StatelessWidget {
  const _AutocompleteRow({
    required this.item,
    required this.isSelected,
    required this.isDesktop,
    required this.rowHeight,
    required this.onTap,
    required this.onHover,
    required this.onContinue,
  });

  final AcItem item;
  final bool isSelected;
  final bool isDesktop;
  final double rowHeight;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final Widget leadingIcon;
    switch (item.kind) {
      case AcKind.note:
        leadingIcon = Icon(
          Icons.description_outlined,
          size: isDesktop ? 16 : 22,
          color: theme.colorScheme.primary,
        );
      case AcKind.alias:
        leadingIcon = Icon(
          Icons.subdirectory_arrow_right,
          size: isDesktop ? 16 : 22,
          color: theme.colorScheme.tertiary,
        );
      case AcKind.attachment:
        leadingIcon = Icon(
          Icons.attach_file,
          size: isDesktop ? 16 : 22,
          color: theme.colorScheme.secondary,
        );
      case AcKind.heading:
        leadingIcon = Container(
          width: isDesktop ? 20 : 26,
          alignment: Alignment.center,
          child: Text(
            item.secondary ?? 'H',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 11 : 13,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      case AcKind.block:
        leadingIcon = Icon(
          Icons.tag,
          size: isDesktop ? 16 : 22,
          color: theme.colorScheme.secondary,
        );
      default:
        leadingIcon = Icon(
          Icons.text_snippet_outlined,
          size: isDesktop ? 16 : 22,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }

    final normalStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: isDesktop ? 13 : 15,
          color: theme.colorScheme.onSurface,
        ) ??
        const TextStyle();

    final titleSpans = _buildSpans(item.primary, item.matchRanges, normalStyle);

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Semantics(
        label: '${item.primary} ${item.secondary ?? ''}',
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: rowHeight,
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12.0 : 16.0),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            child: Row(
              children: [
                leadingIcon,
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: titleSpans),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (item.secondary != null && item.kind != AcKind.heading) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.secondary!,
                    style: normalStyle.copyWith(
                      fontSize: isDesktop ? 12 : 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
                if (!isDesktop && item.kind == AcKind.note) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: const Text(
                        '#',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      tooltip: l10n.autocompleteContinue,
                      onPressed: onContinue,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(
    String text,
    List<(int, int)> ranges,
    TextStyle baseStyle,
  ) {
    if (ranges.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var last = 0;

    for (final (start, end) in ranges) {
      if (start > last && start <= text.length) {
        spans.add(
          TextSpan(text: text.substring(last, start), style: baseStyle),
        );
      }
      if (start < text.length && end <= text.length && end >= start) {
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }
      last = end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return spans;
  }
}
