// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextRange;

import 'lp_decoration.dart';
import 'reveal.dart';

/// Strategy for hiding inactive markdown syntax markers.
enum LpHideMode {
  /// Font size 0.01 with transparent color. Markers take virtually zero space.
  zeroSize,

  /// Same font size as base text but transparent color. Offsets and layout width match source mode.
  transparent,
}

/// Active hiding strategy for this platform.
const LpHideMode kLpHideMode = LpHideMode.zeroSize;

/// Zero-size style used for hidden syntax markers.
const TextStyle kZeroSizeStyle = TextStyle(
  fontSize: 0.01,
  color: Colors.transparent,
  letterSpacing: 0,
  height: 0.01,
);

/// Font scale factors for headings 1 through 6.
const List<double> kHeadingScales = [2.0, 1.6, 1.35, 1.2, 1.1, 1.0];

/// Builds an [InlineSpan] tree for a single line in Live Preview mode.
///
/// Guaranteed invariant:
/// `span.toPlainText(includePlaceholders: true).length == lineEnd - lineStart`.
TextSpan buildLpLine({
  required String lineText,
  required int lineStart,
  required int lineEnd,
  required List<LpDecoration> decorations,
  required TextRange active,
  required TextStyle base,
  ColorScheme? colorScheme,
  bool useWidgets = false,
  LpHideMode hideMode = kLpHideMode,
  void Function(String target)? onInternalLinkTap,
  void Function(String url)? onExternalLinkTap,
  void Function(String target, Rect rect)? onInternalLinkHover,
  Set<int>? foldedCallouts,
}) {
  assert(
    lineEnd - lineStart == lineText.length,
    'lineEnd ($lineEnd) - lineStart ($lineStart) must equal lineText.length (${lineText.length})',
  );

  if (lineStart == lineEnd) {
    return TextSpan(text: '', style: base);
  }

  // 1. Filter decorations overlapping [lineStart, lineEnd)
  final lineDecos = <LpDecoration>[];
  for (final d in decorations) {
    if (d.start < lineEnd && d.end > lineStart) {
      lineDecos.add(d);
    }
  }

  // 2. Collect all segment boundaries inside [lineStart, lineEnd]
  final boundarySet = <int>{lineStart, lineEnd};
  for (final d in lineDecos) {
    boundarySet.add(d.start.clamp(lineStart, lineEnd));
    boundarySet.add(d.end.clamp(lineStart, lineEnd));
  }
  final boundaries = boundarySet.toList()..sort();

  final spans = <InlineSpan>[];

  // Helper to construct transparent style
  TextStyle makeTransparent(TextStyle st) =>
      st.copyWith(color: Colors.transparent);

  // 3. Process each segment
  for (var i = 0; i < boundaries.length - 1; i++) {
    final segStart = boundaries[i];
    final segEnd = boundaries[i + 1];
    if (segStart >= segEnd) continue;

    final segText = lineText.substring(
      segStart - lineStart,
      segEnd - lineStart,
    );

    // Find decorations covering this segment
    final segDecos = lineDecos
        .where((d) => d.start <= segStart && d.end >= segEnd)
        .toList();

    // Check if segment is hidden
    var isHidden = false;
    var isRevealedMarker = false;
    for (final d in segDecos) {
      if (d is LpHide) {
        if (!isRevealed(d, active)) {
          isHidden = true;
          break;
        } else {
          isRevealedMarker = true;
        }
      }
    }

    // Check if covered by an unrevealed widget
    LpWidget? activeWidget;
    for (final d in segDecos) {
      if (d is LpWidget) {
        if (!isRevealed(d, active)) {
          activeWidget = d;
          break;
        }
      }
    }

    // Check replaceChar
    String? replaceChar;
    for (final d in segDecos) {
      if (d is LpReplaceChar && !isHidden) {
        replaceChar = d.char;
        break;
      }
    }

    // Handle widget mode or fallback
    if (activeWidget != null) {
      if (useWidgets) {
        final codeUnit = segText.codeUnitAt(0);
        final isSurrogate = codeUnit >= 0xD800 && codeUnit <= 0xDFFF;

        if (segStart == activeWidget.start && !isSurrogate) {
          // Emit WidgetSpan for first UTF-16 unit (takes exactly 1 unit placeholder)
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    color: colorScheme?.primary ?? Colors.blue,
                  ),
                ),
              ),
            ),
          );

          if (segText.length > 1) {
            final remainingText = segText.substring(1);
            spans.add(
              TextSpan(
                text: remainingText,
                style: hideMode == LpHideMode.zeroSize
                    ? kZeroSizeStyle
                    : makeTransparent(base),
              ),
            );
          }
          continue;
        } else {
          // Lines or segments after the first character of the widget are hidden
          spans.add(
            TextSpan(
              text: segText,
              style: hideMode == LpHideMode.zeroSize
                  ? kZeroSizeStyle
                  : makeTransparent(base),
            ),
          );
          continue;
        }
      } else {
        // useWidgets == false -> Fallback styling per sub-step 6
        if (activeWidget.kind == LpWidgetKind.calloutHeader) {
          // calloutHeader: hide '>' and '[!type]' markers, show title bold with callout tint
          final match = RegExp(
            r'^(\s*(?:>\s?)*)(?:(\[![\w-]+\][+-]?\s*))?(.*)$',
          ).firstMatch(segText);
          if (match != null) {
            final prefix = match.group(1) ?? '';
            final tag = match.group(2) ?? '';
            final title = match.group(3) ?? '';

            if (prefix.isNotEmpty || tag.isNotEmpty) {
              spans.add(
                TextSpan(
                  text: prefix + tag,
                  style: hideMode == LpHideMode.zeroSize
                      ? kZeroSizeStyle
                      : makeTransparent(base),
                ),
              );
            }
            if (title.isNotEmpty) {
              spans.add(
                TextSpan(
                  text: title,
                  style: base.copyWith(
                    fontWeight: FontWeight.bold,
                    backgroundColor:
                        (colorScheme?.primaryContainer ??
                                const Color(0xFFE8DEF8))
                            .withValues(alpha: 0.25),
                  ),
                ),
              );
            }
            continue;
          }
        }
      }
    }

    if (isHidden) {
      spans.add(
        TextSpan(
          text: segText,
          style: hideMode == LpHideMode.zeroSize
              ? kZeroSizeStyle
              : makeTransparent(base),
        ),
      );
      continue;
    }

    // Compute styles
    final styleDecos = segDecos.whereType<LpStyle>().toList();
    if (isRevealedMarker) {
      styleDecos.add(const LpStyle(0, 0, LpStyleKind.syntaxMarker));
    }

    // Fallback styling for active widgets when useWidgets == false
    if (activeWidget != null && !useWidgets) {
      switch (activeWidget.kind) {
        case LpWidgetKind.checkbox:
          styleDecos.add(const LpStyle(0, 0, LpStyleKind.inlineCode));
        case LpWidgetKind.embed:
        case LpWidgetKind.image:
          styleDecos.add(
            LpStyle(
              0,
              0,
              LpStyleKind.internalLink,
              data:
                  activeWidget.data['target'] as String? ??
                  activeWidget.data['url'] as String?,
            ),
          );
        case LpWidgetKind.inlineMath:
        case LpWidgetKind.mathBlock:
        case LpWidgetKind.table:
        case LpWidgetKind.queryBlock:
          styleDecos.add(const LpStyle(0, 0, LpStyleKind.codeLine));
        case LpWidgetKind.horizontalRule:
          styleDecos.add(const LpStyle(0, 0, LpStyleKind.comment));
        case LpWidgetKind.calloutHeader:
          styleDecos.add(const LpStyle(0, 0, LpStyleKind.calloutLine));
      }
    }

    // Sort by priority
    styleDecos.sort((a, b) => _priority(a.kind).compareTo(_priority(b.kind)));

    var merged = base;
    String? linkTarget;
    var isInternalLink = false;
    var isExternalLink = false;

    for (final s in styleDecos) {
      switch (s.kind) {
        case LpStyleKind.codeLine:
          merged = merged.copyWith(fontFamily: 'RobotoMono');
        case LpStyleKind.quoteLine:
          merged = merged.copyWith(
            backgroundColor:
                (colorScheme?.surfaceContainerHighest ??
                        const Color(0x33888888))
                    .withValues(alpha: 0.15),
          );
        case LpStyleKind.calloutLine:
          merged = merged.copyWith(
            backgroundColor:
                (colorScheme?.primaryContainer ?? const Color(0xFFE8DEF8))
                    .withValues(alpha: 0.20),
          );
        case LpStyleKind.heading:
          final lvl = s.level.clamp(1, 6);
          final scale = kHeadingScales[lvl - 1];
          merged = merged.copyWith(
            fontSize: (base.fontSize ?? 16.0) * scale,
            fontWeight: FontWeight.bold,
          );
        case LpStyleKind.bold:
          merged = merged.copyWith(fontWeight: FontWeight.bold);
        case LpStyleKind.italic:
          merged = merged.copyWith(fontStyle: FontStyle.italic);
        case LpStyleKind.strike:
          merged = merged.copyWith(decoration: TextDecoration.lineThrough);
        case LpStyleKind.highlight:
          merged = merged.copyWith(backgroundColor: const Color(0x66FFF176));
        case LpStyleKind.inlineCode:
          merged = merged.copyWith(
            fontFamily: 'RobotoMono',
            backgroundColor:
                (colorScheme?.surfaceContainerHighest ??
                        const Color(0x33888888))
                    .withValues(alpha: 0.35),
          );
        case LpStyleKind.internalLink:
          isInternalLink = true;
          linkTarget = s.data;
          merged = merged.copyWith(
            color: colorScheme?.primary ?? const Color(0xFF7C4DFF),
            decoration: TextDecoration.underline,
          );
        case LpStyleKind.externalLink:
          isExternalLink = true;
          linkTarget = s.data;
          merged = merged.copyWith(
            color: colorScheme?.secondary ?? const Color(0xFF64B5F6),
            decoration: TextDecoration.underline,
          );
        case LpStyleKind.tag:
          merged = merged.copyWith(
            color: colorScheme?.primary ?? const Color(0xFF7C4DFF),
          );
        case LpStyleKind.taskDone:
          merged = merged.copyWith(
            decoration: TextDecoration.lineThrough,
            color: (colorScheme?.onSurface ?? Colors.black).withValues(
              alpha: 0.45,
            ),
          );
        case LpStyleKind.comment:
          merged = merged.copyWith(
            color: (colorScheme?.onSurface ?? Colors.black).withValues(
              alpha: 0.45,
            ),
          );
        case LpStyleKind.blockId:
          merged = merged.copyWith(
            color: (colorScheme?.onSurface ?? Colors.black).withValues(
              alpha: 0.40,
            ),
          );
        case LpStyleKind.footnoteRef:
          merged = merged.copyWith(
            fontSize: (merged.fontSize ?? base.fontSize ?? 16.0) * 0.85,
            color: colorScheme?.primary ?? const Color(0xFF7C4DFF),
          );
        case LpStyleKind.syntaxMarker:
          merged = merged.copyWith(
            color: (colorScheme?.onSurface ?? Colors.black).withValues(
              alpha: 0.40,
            ),
          );
        case LpStyleKind.searchMatch:
          merged = merged.copyWith(backgroundColor: const Color(0x88FFEB3B));
      }
    }

    MouseCursor? cursor;
    GestureRecognizer? recognizer;
    void Function(PointerEnterEvent)? onEnter;
    void Function(PointerExitEvent)? onExit;

    if (isInternalLink && linkTarget != null) {
      cursor = SystemMouseCursors.click;
      if (onInternalLinkTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onInternalLinkTap(linkTarget!);
      }
      if (onInternalLinkHover != null) {
        onEnter = (event) {
          onInternalLinkHover(
            linkTarget!,
            Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
          );
        };
      }
    } else if (isExternalLink && linkTarget != null) {
      cursor = SystemMouseCursors.click;
      if (onExternalLinkTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onExternalLinkTap(linkTarget!);
      }
    }

    if (replaceChar != null) {
      spans.add(
        TextSpan(
          text: replaceChar,
          style: merged,
          mouseCursor: cursor,
          recognizer: recognizer,
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: segText,
          style: merged,
          mouseCursor: cursor,
          recognizer: recognizer,
          onEnter: onEnter,
          onExit: onExit,
        ),
      );
    }
  }

  final result = TextSpan(children: spans, style: base);
  assert(
    result.toPlainText(includePlaceholders: true).length == lineEnd - lineStart,
    'Span length (${result.toPlainText(includePlaceholders: true).length}) must equal source line length (${lineEnd - lineStart})',
  );
  return result;
}

int _priority(LpStyleKind kind) {
  switch (kind) {
    case LpStyleKind.codeLine:
      return 1;
    case LpStyleKind.quoteLine:
      return 2;
    case LpStyleKind.calloutLine:
      return 3;
    case LpStyleKind.heading:
      return 4;
    case LpStyleKind.bold:
      return 5;
    case LpStyleKind.italic:
      return 6;
    case LpStyleKind.strike:
      return 7;
    case LpStyleKind.highlight:
      return 8;
    case LpStyleKind.inlineCode:
      return 9;
    case LpStyleKind.internalLink:
    case LpStyleKind.externalLink:
      return 10;
    case LpStyleKind.tag:
      return 11;
    case LpStyleKind.taskDone:
      return 12;
    case LpStyleKind.comment:
      return 13;
    case LpStyleKind.blockId:
      return 14;
    case LpStyleKind.footnoteRef:
      return 15;
    case LpStyleKind.syntaxMarker:
      return 16;
    case LpStyleKind.searchMatch:
      return 17;
  }
}
