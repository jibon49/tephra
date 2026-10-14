// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import 'reading_controller.dart';
import 'reading_styles.dart';

/// Information regarding a tapped internal wiki link.
final class WikiLinkTap {
  const WikiLinkTap({
    required this.target,
    this.heading,
    this.blockRef,
    this.newTab = false,
  });

  final String target;
  final String? heading;
  final String? blockRef;
  final bool newTab;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WikiLinkTap &&
          target == other.target &&
          heading == other.heading &&
          blockRef == other.blockRef &&
          newTab == other.newTab;

  @override
  int get hashCode => Object.hash(target, heading, blockRef, newTab);

  @override
  String toString() =>
      'WikiLinkTap(target: $target, heading: $heading, blockRef: $blockRef, newTab: $newTab)';
}

/// Inherited scope providing parsed note context and theme styles to block widgets.
class ReadingScope extends InheritedWidget {
  const ReadingScope({
    super.key,
    required this.path,
    required this.parsed,
    required this.text,
    required this.styles,
    required this.footnoteNumbers,
    required this.readOnly,
    required this.toggledCallouts,
    this.unresolvedLinks = const {},
    this.onToggleCallout,
    this.onToggleTask,
    this.onOpenWikiLink,
    this.onOpenMarkdownLink,
    this.onOpenUrl,
    this.controller,
    this.onLinkEnter,
    this.onLinkExit,
    this.onLinkLongPress,
    required super.child,
  });

  final VaultPath path;
  final ParsedNote parsed;
  final String text;
  final ReadingStyles styles;
  final Map<String, int> footnoteNumbers;
  final bool readOnly;
  final Set<int> toggledCallouts;
  final Set<String> unresolvedLinks;
  final void Function(int startOffset)? onToggleCallout;
  final Future<void> Function(TaskItem task, String newStatus)? onToggleTask;
  final void Function(WikiLinkTap tap)? onOpenWikiLink;
  final void Function(String url, {bool newTab})? onOpenMarkdownLink;
  final void Function(Uri uri)? onOpenUrl;
  final ReadingViewController? controller;
  final void Function(
    BuildContext context,
    String target,
    String? heading,
    String? blockRef,
    Offset position,
  )?
  onLinkEnter;
  final void Function(String target)? onLinkExit;
  final void Function(
    BuildContext context,
    String target,
    String? heading,
    String? blockRef,
    Offset position,
  )?
  onLinkLongPress;

  static ReadingScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ReadingScope>();
    assert(scope != null, 'No ReadingScope found in context');
    return scope!;
  }

  static ReadingScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ReadingScope>();
  }

  @override
  bool updateShouldNotify(ReadingScope oldWidget) {
    return path != oldWidget.path ||
        parsed != oldWidget.parsed ||
        text != oldWidget.text ||
        styles != oldWidget.styles ||
        readOnly != oldWidget.readOnly ||
        controller != oldWidget.controller ||
        toggledCallouts != oldWidget.toggledCallouts;
  }
}
