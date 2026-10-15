// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor_controller.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_popup.dart';

/// Overlay widget wrapping the editor and displaying [AutocompletePopup] when visible.
class AutocompleteOverlay extends ConsumerStatefulWidget {
  const AutocompleteOverlay({
    super.key,
    required this.tabId,
    required this.controller,
    required this.child,
  });

  final String tabId;
  final EditorController controller;
  final Widget child;

  @override
  ConsumerState<AutocompleteOverlay> createState() =>
      _AutocompleteOverlayState();
}

class _AutocompleteOverlayState extends ConsumerState<AutocompleteOverlay> {
  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(AutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.tabId != widget.tabId) {
      _attach();
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

  @override
  Widget build(BuildContext context) {
    final acState = ref.watch(autocompleteControllerProvider(widget.tabId));
    final notifier = ref.read(
      autocompleteControllerProvider(widget.tabId).notifier,
    );

    ref.listen<AutocompleteState>(
      autocompleteControllerProvider(widget.tabId),
      (prev, next) {
        if ((prev == null || !prev.visible) && next.visible) {
          final isDesktop = MediaQuery.sizeOf(context).width >= 840;
          if (!isDesktop) {
            final caret = widget.controller.selection.baseOffset;
            widget.controller.revealOffset(caret, center: false);
          }
        }
      },
    );

    if (!acState.visible) {
      return widget.child;
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return Stack(
      children: [
        widget.child,
        // Dismiss barrier for clicks outside the popup
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: notifier.hide,
            // Allow pointer down to dismiss
            onPanDown: isDesktop ? null : (_) => notifier.hide(),
          ),
        ),
        AutocompletePopup(
          tabId: widget.tabId,
          controller: widget.controller,
          state: acState,
        ),
      ],
    );
  }
}
