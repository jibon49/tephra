// © 2026 Tephra. All rights reserved.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'inline_builder.dart';
import 'reading_scope.dart';

/// Renders a list of inline Markdown nodes as rich text with gesture lifecycle management.
class InlineText extends StatefulWidget {
  const InlineText({
    super.key,
    required this.nodes,
    this.style,
    this.textAlign,
  });

  InlineText.fromNode(MdNode node, {super.key, this.style, this.textAlign})
    : nodes = node.children;

  final List<MdNode> nodes;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<InlineText> {
  InlineSpan? _span;
  List<GestureRecognizer> _recognizers = const [];
  bool _needsRebuild = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _needsRebuild = true;
  }

  @override
  void didUpdateWidget(InlineText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nodes != oldWidget.nodes || widget.style != oldWidget.style) {
      _needsRebuild = true;
    }
  }

  void _rebuildIfNeeded() {
    if (!_needsRebuild) return;
    for (final r in _recognizers) {
      r.dispose();
    }
    final scope = ReadingScope.maybeOf(context);
    final baseStyle =
        widget.style ??
        scope?.styles.body ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle();

    final result = InlineBuilder.build(widget.nodes, baseStyle, context);
    _span = result.span;
    _recognizers = result.recognizers;
    _needsRebuild = false;
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = const [];
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _rebuildIfNeeded();
    return Text.rich(_span ?? const TextSpan(), textAlign: widget.textAlign);
  }
}
