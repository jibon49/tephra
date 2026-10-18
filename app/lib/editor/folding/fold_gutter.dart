// © 2026 Tephra. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'fold_controller.dart';
import 'fold_regions.dart';

/// Representation of a visible paragraph's line index and vertical bounds in the gutter.
final class FoldGutterParagraph {
  const FoldGutterParagraph({
    required this.index,
    required this.top,
    required this.height,
  });

  final int index;
  final double top;
  final double height;
}

/// Fold gutter widget displaying chevrons for collapsible headings and list items.
final class FoldGutter extends StatefulWidget {
  const FoldGutter({
    super.key,
    required this.controller,
    this.lineHeight = 24.0,
    this.lineCount,
    this.paragraphsNotifier,
  });

  final FoldController controller;
  final double lineHeight;
  final int? lineCount;
  final ValueListenable<List<FoldGutterParagraph>?>? paragraphsNotifier;

  @override
  State<FoldGutter> createState() => _FoldGutterState();
}

class _FoldGutterState extends State<FoldGutter> {
  int? _hoveredLine;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.paragraphsNotifier?.addListener(_onParagraphsChanged);
  }

  @override
  void didUpdateWidget(covariant FoldGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.paragraphsNotifier != widget.paragraphsNotifier) {
      oldWidget.paragraphsNotifier?.removeListener(_onParagraphsChanged);
      widget.paragraphsNotifier?.addListener(_onParagraphsChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.paragraphsNotifier?.removeListener(_onParagraphsChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onParagraphsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final totalLines =
        widget.lineCount ??
        (widget.controller.lines.lineCount > 0
            ? widget.controller.lines.lineCount
            : 1);

    // Build a map of unfold line number -> FoldRegion
    final lineToRegion = <int, FoldRegion>{};
    for (final r in widget.controller.regions) {
      final line = widget.controller.lines.lineOf(r.headerStart);
      lineToRegion[line] = r;
    }

    if (widget.paragraphsNotifier != null &&
        widget.paragraphsNotifier!.value != null) {
      final paragraphs = widget.paragraphsNotifier!.value!;
      final gutterWidth = isPhone ? 24.0 : 20.0;

      return SizedBox(
        width: gutterWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final p in paragraphs)
              if (lineToRegion.containsKey(p.index))
                Positioned(
                  top: p.top,
                  left: 0,
                  width: gutterWidth,
                  height: p.height,
                  child: _buildChevronItem(
                    line: p.index,
                    region: lineToRegion[p.index]!,
                    isPhone: isPhone,
                    height: p.height,
                  ),
                ),
          ],
        ),
      );
    }

    // Fallback or test mode: list of lines
    final gutterWidth = isPhone ? 24.0 : 20.0;

    return SizedBox(
      width: gutterWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < totalLines; i++)
            SizedBox(
              height: widget.lineHeight,
              child: lineToRegion.containsKey(i)
                  ? _buildChevronItem(
                      line: i,
                      region: lineToRegion[i]!,
                      isPhone: isPhone,
                      height: widget.lineHeight,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildChevronItem({
    required int line,
    required FoldRegion region,
    required bool isPhone,
    required double height,
  }) {
    final isFolded = widget.controller.isFolded(region.headerStart);
    final isHovered = _hoveredLine == line;
    final isVisible = isPhone || isFolded || isHovered;

    final icon = isFolded
        ? Icons.keyboard_arrow_right
        : Icons.keyboard_arrow_down;

    Widget chevronWidget = Icon(
      icon,
      size: isPhone ? 24.0 : 16.0,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
    );

    if (isPhone) {
      chevronWidget = OverflowBox(
        minWidth: 48,
        maxWidth: 48,
        minHeight: 48,
        maxHeight: 48,
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(width: 24, height: 24, child: chevronWidget),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredLine = line),
      onExit: (_) => setState(() {
        if (_hoveredLine == line) _hoveredLine = null;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.controller.toggle(region.headerStart);
        },
        child: Opacity(
          opacity: isVisible ? 1.0 : 0.0,
          child: Center(child: chevronWidget),
        ),
      ),
    );
  }
}
