// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'embeds/embed_view.dart';
import 'reading_scope.dart';

/// Returns true if [node] is hidden from the reading view.
bool isHiddenInline(MdNode node) =>
    node is MdCommentInline || node is MdBlockId;

/// Result of building inline Markdown spans and active gesture recognizers.
final class InlineBuildResult {
  const InlineBuildResult(this.span, this.recognizers);

  final InlineSpan span;
  final List<GestureRecognizer> recognizers;
}

/// Tap gesture recognizer that also detects long-press gestures for link previews.
class LinkGestureRecognizer extends TapGestureRecognizer {
  LinkGestureRecognizer({super.debugOwner});

  GestureLongPressCallback? onLongPress;
  Timer? _longPressTimer;
  Offset? _longPressPosition;
  bool _didLongPress = false;

  bool get didLongPress => _didLongPress;
  Offset? get longPressPosition => _longPressPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _didLongPress = false;
    _longPressPosition = event.position;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(kLongPressTimeout, () {
      _didLongPress = true;
      resolve(GestureDisposition.accepted);
      onLongPress?.call();
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerMoveEvent) {
      if (_longPressPosition != null &&
          (event.position - _longPressPosition!).distance > kTouchSlop) {
        _longPressTimer?.cancel();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _longPressTimer?.cancel();
    }
  }

  @override
  void rejectGesture(int pointer) {
    _longPressTimer?.cancel();
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}

/// Builds rich inline spans from Markdown AST nodes.
final class InlineBuilder {
  const InlineBuilder._();

  /// Injectable recognizer factory for testing recognizer disposal.
  static TapGestureRecognizer Function() recognizerFactory =
      LinkGestureRecognizer.new;

  /// Builds an [InlineSpan] and collects all gesture recognizers for [nodes].
  static InlineBuildResult build(
    List<MdNode> nodes,
    TextStyle baseStyle,
    BuildContext context,
  ) {
    final scope = ReadingScope.maybeOf(context);
    final theme = Theme.of(context);
    final styles = scope?.styles;
    final recognizers = <GestureRecognizer>[];

    late final InlineSpan Function(MdNode node, TextStyle currentStyle)
    buildNode;

    List<InlineSpan> buildChildren(
      List<MdNode> childNodes,
      TextStyle currentStyle,
    ) {
      final spans = <InlineSpan>[];
      for (final child in childNodes) {
        spans.add(buildNode(child, currentStyle));
      }
      return spans;
    }

    buildNode = (MdNode node, TextStyle currentStyle) {
      switch (node) {
        case MdText():
          return TextSpan(text: node.text, style: currentStyle);

        case MdEmphasis():
          final s = currentStyle.copyWith(fontStyle: FontStyle.italic);
          return TextSpan(style: s, children: buildChildren(node.children, s));

        case MdStrong():
          final s = currentStyle.copyWith(fontWeight: FontWeight.w700);
          return TextSpan(style: s, children: buildChildren(node.children, s));

        case MdStrikethrough():
          final s = currentStyle.copyWith(
            decoration: TextDecoration.lineThrough,
          );
          return TextSpan(style: s, children: buildChildren(node.children, s));

        case MdHighlight():
          final s = currentStyle.copyWith(
            backgroundColor:
                styles?.highlightBackground ?? const Color(0xAAFFEB3B),
          );
          return TextSpan(style: s, children: buildChildren(node.children, s));

        case MdInlineCode():
          final s = (styles?.mono ?? const TextStyle(fontFamily: 'monospace'))
              .copyWith(
                fontSize: (currentStyle.fontSize ?? 16.0) * 0.9,
                backgroundColor:
                    styles?.codeBackground ??
                    theme.colorScheme.surfaceContainerHighest,
              );
          return TextSpan(text: node.code, style: s);

        case MdSoftBreak():
        case MdHardBreak():
          return TextSpan(text: '\n', style: currentStyle);

        case MdCommentInline():
        case MdBlockId():
          return const TextSpan(text: '');

        case MdHtmlInline():
          final lower = node.html.trim().toLowerCase();
          if (lower == '<br>' || lower == '<br/>' || lower == '<br />') {
            return const TextSpan(text: '\n');
          }
          return TextSpan(
            text: node.html,
            style: currentStyle.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

        case MdInlineMath():
          final s = (styles?.mono ?? const TextStyle(fontFamily: 'monospace'))
              .copyWith(
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
              );
          return TextSpan(text: node.tex, style: s);

        case MdTag():
          final s = TextStyle(
            color: theme.colorScheme.primary,
            backgroundColor: styles?.tagBackground,
          );
          return TextSpan(text: '#${node.name}', style: s);

        case MdAutolink():
          final recognizer = recognizerFactory();
          recognizers.add(recognizer);
          recognizer.onTap = () {
            final uri = Uri.tryParse(node.url);
            if (uri != null) {
              scope?.onOpenUrl?.call(uri);
            }
          };

          final rawText = scope?.text;
          final displayText =
              rawText != null &&
                  node.start < rawText.length &&
                  node.end <= rawText.length
              ? () {
                  final sub = rawText.substring(node.start, node.end);
                  if (sub.startsWith('<') && sub.endsWith('>')) {
                    return sub.substring(1, sub.length - 1);
                  }
                  return sub;
                }()
              : node.url;

          final s = TextStyle(
            color: styles?.linkColor ?? theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          );
          return TextSpan(text: displayText, style: s, recognizer: recognizer);

        case MdLink():
          if (node.image) {
            final alt = node.children
                .whereType<MdText>()
                .map((t) => t.text)
                .join();
            if (scope != null) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: EmbedView.markdown(
                  url: node.url,
                  alt: alt,
                  from: scope.path,
                ),
              );
            }
            return TextSpan(text: alt, style: currentStyle);
          }

          final isExternal = Uri.tryParse(node.url)?.hasScheme == true;
          final pathPart = isExternal
              ? ''
              : LinkFormatter.decodeMarkdownPath(node.url.split('#').first);
          final fragment = !isExternal && node.url.contains('#')
              ? node.url.split('#').last
              : null;
          final heading = fragment != null && !fragment.startsWith('^')
              ? fragment
              : null;
          final blockRef = fragment != null && fragment.startsWith('^')
              ? fragment.substring(1)
              : null;

          final recognizer = recognizerFactory();
          recognizers.add(recognizer);

          if (recognizer is LinkGestureRecognizer &&
              !isExternal &&
              pathPart.isNotEmpty) {
            recognizer.onLongPress = () {
              scope?.onLinkLongPress?.call(
                context,
                pathPart,
                heading,
                blockRef,
                recognizer.longPressPosition ?? Offset.zero,
              );
            };
          }

          recognizer.onTap = () {
            if (recognizer is LinkGestureRecognizer &&
                recognizer.didLongPress) {
              return;
            }
            final isCtrl = HardwareKeyboard.instance.isControlPressed;
            scope?.onOpenMarkdownLink?.call(node.url, newTab: isCtrl);
          };

          final isUnresolvedLink =
              !isExternal &&
              pathPart.isNotEmpty &&
              (scope?.unresolvedLinks.contains(pathPart) ?? false);
          final baseColor = styles?.linkColor ?? theme.colorScheme.primary;
          final linkColor = isUnresolvedLink
              ? baseColor.withValues(alpha: 0.6)
              : baseColor;
          final s = TextStyle(
            color: linkColor,
            decoration: isExternal ? TextDecoration.underline : null,
          );
          return TextSpan(
            style: s,
            recognizer: recognizer,
            onEnter: !isExternal && pathPart.isNotEmpty
                ? (event) => scope?.onLinkEnter?.call(
                    context,
                    pathPart,
                    heading,
                    blockRef,
                    event.position,
                  )
                : null,
            onExit: !isExternal && pathPart.isNotEmpty
                ? (_) => scope?.onLinkExit?.call(pathPart)
                : null,
            children: buildChildren(node.children, s),
          );

        case MdWikiLink():
          if (node.embed) {
            if (scope != null) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: EmbedView.wiki(node: node, from: scope.path),
              );
            }
            return TextSpan(text: node.target, style: currentStyle);
          }

          final String displayText;
          if (node.alias != null) {
            displayText = node.alias!;
          } else {
            if (node.target.isEmpty) {
              displayText = node.heading ?? '^${node.blockRef ?? ''}';
            } else {
              var t = node.target;
              if (node.heading != null && node.target.isNotEmpty) {
                t += ' > ${node.heading}';
              } else if (node.blockRef != null && node.target.isNotEmpty) {
                t += ' > ^${node.blockRef}';
              }
              displayText = t;
            }
          }

          final recognizer = recognizerFactory();
          recognizers.add(recognizer);

          if (recognizer is LinkGestureRecognizer && node.target.isNotEmpty) {
            recognizer.onLongPress = () {
              scope?.onLinkLongPress?.call(
                context,
                node.target,
                node.heading,
                node.blockRef,
                recognizer.longPressPosition ?? Offset.zero,
              );
            };
          }

          void handleTap(bool newTab) {
            scope?.onOpenWikiLink?.call(
              WikiLinkTap(
                target: node.target,
                heading: node.heading,
                blockRef: node.blockRef,
                newTab: newTab,
              ),
            );
          }

          recognizer.onTap = () {
            if (recognizer is LinkGestureRecognizer &&
                recognizer.didLongPress) {
              return;
            }
            final isCtrl = HardwareKeyboard.instance.isControlPressed;
            handleTap(isCtrl);
          };
          recognizer.onSecondaryTapUp = (_) => handleTap(true);
          recognizer.onTertiaryTapUp = (_) => handleTap(true);

          final isUnresolved =
              node.target.isNotEmpty &&
              (scope?.unresolvedLinks.contains(node.target) ?? false);
          final baseWikiColor = styles?.linkColor ?? theme.colorScheme.primary;
          final wikiLinkColor = isUnresolved
              ? baseWikiColor.withValues(alpha: 0.6)
              : baseWikiColor;
          final s = TextStyle(color: wikiLinkColor);
          return TextSpan(
            text: displayText,
            style: s,
            recognizer: recognizer,
            onEnter: node.target.isNotEmpty
                ? (event) => scope?.onLinkEnter?.call(
                    context,
                    node.target,
                    node.heading,
                    node.blockRef,
                    event.position,
                  )
                : null,
            onExit: node.target.isNotEmpty
                ? (_) => scope?.onLinkExit?.call(node.target)
                : null,
          );

        case MdFootnoteRef():
          final num = scope?.footnoteNumbers[node.label]?.toString() ?? '?';
          return WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: GestureDetector(
              onTap: () {
                if (scope != null) {
                  scope.controller?.scrollToOffset(scope.parsed.root.end);
                }
              },
              child: Text(
                num,
                style: TextStyle(
                  fontSize: (currentStyle.fontSize ?? 16.0) * 0.75,
                  color: styles?.linkColor ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );

        case MdInlineFootnote():
          final label = 'inline-${node.start}';
          final num = scope?.footnoteNumbers[label]?.toString() ?? '?';
          return WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: GestureDetector(
              onTap: () {
                if (scope != null) {
                  scope.controller?.scrollToOffset(scope.parsed.root.end);
                }
              },
              child: Text(
                num,
                style: TextStyle(
                  fontSize: (currentStyle.fontSize ?? 16.0) * 0.75,
                  color: styles?.linkColor ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );

        default:
          return TextSpan(
            style: currentStyle,
            children: buildChildren(node.children, currentStyle),
          );
      }
    };

    final children = <InlineSpan>[];
    for (final node in nodes) {
      children.add(buildNode(node, baseStyle));
    }

    return InlineBuildResult(
      TextSpan(style: baseStyle, children: children),
      recognizers,
    );
  }
}
