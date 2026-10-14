// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../settings/providers.dart';
import 'page_preview.dart';

class PagePreviewEntry {
  PagePreviewEntry({
    required this.depth,
    required this.from,
    required this.target,
    this.heading,
    this.blockRef,
    required this.position,
    required this.overlayEntry,
  });

  final int depth;
  final VaultPath from;
  final String target;
  final String? heading;
  final String? blockRef;
  final Offset position;
  final OverlayEntry overlayEntry;
  Timer? closeTimer;
}

/// Controller managing the page preview popup stack (max 3 nested popups).
class PagePreviewController {
  PagePreviewController(this.ref);

  final Ref ref;
  final List<PagePreviewEntry> _stack = [];

  Timer? _hoverTimer;
  String? _pendingTarget;

  int get stackDepth => _stack.length;
  List<PagePreviewEntry> get entries => List.unmodifiable(_stack);

  void onLinkEnter({
    required BuildContext context,
    required VaultPath from,
    required String target,
    String? heading,
    String? blockRef,
    required Offset position,
    required int callerDepth,
    required bool isEditor,
  }) {
    if (callerDepth >= 3) return; // depth 3 links do not open more

    _cancelCloseTimerForDepth(callerDepth);
    _hoverTimer?.cancel();
    _pendingTarget = target;

    _hoverTimer = Timer(const Duration(milliseconds: 600), () {
      if (_pendingTarget != target) return;
      final settings = ref.read(appSettingsProvider);
      final requiresCtrl = isEditor
          ? settings.pagePreviewEditorRequiresCtrl
          : settings.pagePreviewReadingRequiresCtrl;

      if (requiresCtrl && !HardwareKeyboard.instance.isControlPressed) {
        return;
      }

      showPreview(
        context: context,
        from: from,
        target: target,
        heading: heading,
        blockRef: blockRef,
        position: position,
        callerDepth: callerDepth,
      );
    });
  }

  void onLinkExit({required String target, required int callerDepth}) {
    if (_pendingTarget == target) {
      _hoverTimer?.cancel();
      _pendingTarget = null;
    }
    _startCloseTimerForDepth(callerDepth + 1);
  }

  void onPopupEnter(int depth) {
    for (var d = 1; d <= depth; d++) {
      _cancelCloseTimerForDepth(d);
    }
  }

  void onPopupExit(int depth) {
    _startCloseTimerForDepth(depth);
  }

  void showPreview({
    required BuildContext context,
    required VaultPath from,
    required String target,
    String? heading,
    String? blockRef,
    required Offset position,
    required int callerDepth,
  }) {
    if (callerDepth >= 3) return; // Refuse opening 4th popup

    final targetDepth = callerDepth + 1;

    // Close any popups at or deeper than targetDepth
    while (_stack.length >= targetDepth) {
      closeTop();
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return PagePreviewPopup(
          depth: targetDepth,
          from: from,
          target: target,
          heading: heading,
          blockRef: blockRef,
          anchorPosition: position,
          onClose: () => closeTop(),
        );
      },
    );

    overlay.insert(entry);

    _stack.add(
      PagePreviewEntry(
        depth: targetDepth,
        from: from,
        target: target,
        heading: heading,
        blockRef: blockRef,
        position: position,
        overlayEntry: entry,
      ),
    );
  }

  void closeTop() {
    if (_stack.isEmpty) return;
    final top = _stack.removeLast();
    top.closeTimer?.cancel();
    top.overlayEntry.remove();
    top.overlayEntry.dispose();
  }

  void closeAll() {
    _hoverTimer?.cancel();
    _pendingTarget = null;
    while (_stack.isNotEmpty) {
      closeTop();
    }
  }

  void closeFromDepth(int depth) {
    while (_stack.isNotEmpty && _stack.last.depth >= depth) {
      closeTop();
    }
  }

  void _startCloseTimerForDepth(int depth) {
    if (depth <= 0 || depth > _stack.length) return;
    final entry = _stack[depth - 1];
    entry.closeTimer?.cancel();
    entry.closeTimer = Timer(const Duration(milliseconds: 300), () {
      closeFromDepth(depth);
    });
  }

  void _cancelCloseTimerForDepth(int depth) {
    if (depth <= 0 || depth > _stack.length) return;
    final entry = _stack[depth - 1];
    entry.closeTimer?.cancel();
    entry.closeTimer = null;
  }

  void dispose() {
    closeAll();
  }
}

/// Provider for [PagePreviewController].
final pagePreviewControllerProvider = Provider<PagePreviewController>((ref) {
  final controller = PagePreviewController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
