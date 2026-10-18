// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../l10n/app_localizations.dart';
import '../reading/embeds/file_chip.dart';
import '../reading/embeds/image_embed.dart';
import '../reading/embeds/note_embed.dart';
import '../reading/reading_controller.dart';
import '../reading/reading_view.dart';
import 'page_preview_controller.dart';
import 'providers.dart';

/// InheritedWidget propagating the current page preview popup nesting depth.
class PagePreviewDepthContext extends InheritedWidget {
  const PagePreviewDepthContext({
    super.key,
    required this.depth,
    required super.child,
  });

  final int depth;

  static PagePreviewDepthContext? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PagePreviewDepthContext>();
  }

  @override
  bool updateShouldNotify(PagePreviewDepthContext oldWidget) =>
      depth != oldWidget.depth;
}

/// Floating popup overlay showing a preview of a linked note or attachment.
class PagePreviewPopup extends ConsumerWidget {
  const PagePreviewPopup({
    super.key,
    required this.depth,
    required this.from,
    required this.target,
    this.heading,
    this.blockRef,
    required this.anchorPosition,
    required this.onClose,
  });

  final int depth;
  final VaultPath from;
  final String target;
  final String? heading;
  final String? blockRef;
  final Offset anchorPosition;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final popupWidth = min(400.0, max(100.0, screenWidth - 32.0));
    final popupHeight = min(500.0, max(100.0, screenHeight * 0.7));

    // Placed below the link if it fits, else above; clamped inside the window with 8 dp margins.
    double top;
    if (anchorPosition.dy + 20 + popupHeight <= screenHeight - 8.0) {
      top = anchorPosition.dy + 20;
    } else if (anchorPosition.dy - 20 - popupHeight >= 8.0) {
      top = anchorPosition.dy - 20 - popupHeight;
    } else {
      top = (screenHeight - popupHeight) / 2;
    }
    top = top.clamp(8.0, max(8.0, screenHeight - popupHeight - 8.0));

    double left = anchorPosition.dx - 20;
    left = left.clamp(8.0, max(8.0, screenWidth - popupWidth - 8.0));

    return PageStorage(
      bucket: PageStorageBucket(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ref.read(pagePreviewControllerProvider).closeTop();
          }
        },
        child: Stack(
          children: [
            // Outside tap closes all popups when at base depth
            if (depth == 1)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (_) {
                    ref.read(pagePreviewControllerProvider).closeAll();
                  },
                ),
              ),
            Positioned(
              top: top,
              left: left,
              width: popupWidth,
              height: popupHeight,
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    ref.read(pagePreviewControllerProvider).closeTop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  onEnter: (_) {
                    ref.read(pagePreviewControllerProvider).onPopupEnter(depth);
                  },
                  onExit: (_) {
                    ref.read(pagePreviewControllerProvider).onPopupExit(depth);
                  },
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    color: theme.colorScheme.surface,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PagePreviewDepthContext(
                        depth: depth,
                        child: PagePreviewContent(
                          from: from,
                          target: target,
                          heading: heading,
                          blockRef: blockRef,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content inside [PagePreviewPopup] rendering the target file or note.
class PagePreviewContent extends ConsumerWidget {
  const PagePreviewContent({
    super.key,
    required this.from,
    required this.target,
    this.heading,
    this.blockRef,
  });

  final VaultPath from;
  final String target;
  final String? heading;
  final String? blockRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final res = ref.watch(linkResolutionProvider((from, target)));

    return res.when(
      data: (resolved) {
        if (resolved == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.previewNotCreated(target),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(linkNavigatorProvider)
                          .open(
                            from: from,
                            target: target,
                            heading: heading,
                            blockRef: blockRef,
                          );
                      ref.read(pagePreviewControllerProvider).closeAll();
                    },
                    child: Text(l10n.previewCreate),
                  ),
                ],
              ),
            ),
          );
        }

        final ext = resolved.extension.toLowerCase();
        if (ImageEmbed.imageExtensions.contains(ext)) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ImageEmbed(path: resolved, semanticsLabel: target),
            ),
          );
        }

        if (ext != 'md' && ext.isNotEmpty) {
          return Center(
            child: FileChip(
              path: resolved,
              subpath: heading != null ? '#$heading' : null,
            ),
          );
        }

        return _PreviewReadingView(
          path: resolved,
          heading: heading,
          blockRef: blockRef,
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          l10n.embedNotFound(target),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

class _PreviewReadingView extends ConsumerStatefulWidget {
  const _PreviewReadingView({required this.path, this.heading, this.blockRef});

  final VaultPath path;
  final String? heading;
  final String? blockRef;

  @override
  ConsumerState<_PreviewReadingView> createState() =>
      _PreviewReadingViewState();
}

class _PreviewReadingViewState extends ConsumerState<_PreviewReadingView> {
  final ReadingViewController _controller = ReadingViewController();
  bool _didScroll = false;

  void _tryScroll() {
    if (_didScroll) return;
    if (widget.heading != null && widget.heading!.isNotEmpty) {
      _controller.scrollToHeading(widget.heading!);
      _didScroll = true;
    } else if (widget.blockRef != null && widget.blockRef!.isNotEmpty) {
      _controller.scrollToBlockRef(widget.blockRef!);
      _didScroll = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textAsync = ref.watch(embedTextProvider(widget.path));

    return textAsync.when(
      data: (text) {
        if (text == null) {
          final l10n = AppLocalizations.of(context);
          return Center(child: Text(l10n.embedNotFound(widget.path.value)));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _tryScroll());

        return ReadingView(
          path: widget.path,
          text: text,
          controller: _controller,
          readOnly: true,
          readableWidth: false,
          onOpenWikiLink: (tap) {
            ref
                .read(linkNavigatorProvider)
                .open(
                  from: widget.path,
                  target: tap.target,
                  heading: tap.heading,
                  blockRef: tap.blockRef,
                  newTab: tap.newTab,
                );
            ref.read(pagePreviewControllerProvider).closeAll();
          },
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          AppLocalizations.of(context).embedNotFound(widget.path.value),
        ),
      ),
    );
  }
}
