// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'find_controller.dart';

/// Compact find & replace toolbar placed above the source editor.
class FindBar extends StatefulWidget {
  const FindBar({required this.controller, super.key});

  final FindController controller;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final TextEditingController _queryController;
  late final TextEditingController _replaceController;
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _replaceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: widget.controller.state.options.query,
    );
    _replaceController = TextEditingController(
      text: widget.controller.state.replaceText,
    );

    widget.controller.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _queryFocus.requestFocus();
        _queryController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _queryController.text.length,
        );
      }
    });
  }

  void _onControllerChanged() {
    final state = widget.controller.state;
    if (_queryController.text != state.options.query) {
      _queryController.text = state.options.query;
    }
    if (_replaceController.text != state.replaceText) {
      _replaceController.text = state.replaceText;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _queryController.dispose();
    _replaceController.dispose();
    _queryFocus.dispose();
    _replaceFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.controller.close();
      return KeyEventResult.handled;
    }

    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyF) {
      _queryFocus.requestFocus();
      _queryController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _queryController.text.length,
      );
      return KeyEventResult.handled;
    }

    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyH) {
      widget.controller.open(replace: true);
      _replaceFocus.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.controller.previous();
      } else {
        widget.controller.next();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.f3) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.controller.previous();
      } else {
        widget.controller.next();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildCounterText(
    BuildContext context,
    FindState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    if (state.error != null) {
      return Text(
        l10n.findInvalidRegex,
        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
      );
    }
    if (state.options.query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (state.matches.isEmpty) {
      return Text(
        l10n.findNoResults,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }

    final total = state.matches.length;
    final current = state.currentIndex + 1;
    final totalStr = state.truncated ? '$total+' : '$total';
    return Text(
      '$current of $totalStr',
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
    );
  }

  Widget _buildToggle({
    required Key key,
    required String label,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: ValueListenableBuilder<FindState>(
          valueListenable: widget.controller,
          builder: (context, state, _) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Find row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            key: const Key('find.query'),
                            controller: _queryController,
                            focusNode: _queryFocus,
                            decoration: InputDecoration(
                              hintText: l10n.findQueryHint,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: widget.controller.setQuery,
                            onSubmitted: (_) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                widget.controller.previous();
                              } else {
                                widget.controller.next();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCounterText(context, state, l10n),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('find.prev'),
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        tooltip: l10n.findPrevious,
                        onPressed: state.matches.isEmpty
                            ? null
                            : widget.controller.previous,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        key: const Key('find.next'),
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        tooltip: l10n.findNext,
                        onPressed: state.matches.isEmpty
                            ? null
                            : widget.controller.next,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),
                      _buildToggle(
                        key: const Key('find.matchCase'),
                        label: 'Aa',
                        tooltip: l10n.findMatchCase,
                        isSelected: state.options.matchCase,
                        onPressed: widget.controller.toggleMatchCase,
                      ),
                      const SizedBox(width: 4),
                      _buildToggle(
                        key: const Key('find.wholeWord'),
                        label: r'\b',
                        tooltip: l10n.findWholeWord,
                        isSelected: state.options.wholeWord,
                        onPressed: widget.controller.toggleWholeWord,
                      ),
                      const SizedBox(width: 4),
                      _buildToggle(
                        key: const Key('find.regex'),
                        label: '.*',
                        tooltip: l10n.findRegex,
                        isSelected: state.options.regex,
                        onPressed: widget.controller.toggleRegex,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('find.close'),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l10n.findClose,
                        onPressed: widget.controller.close,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  // Replace row
                  if (state.showReplace) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              key: const Key('find.replace'),
                              controller: _replaceController,
                              focusNode: _replaceFocus,
                              decoration: InputDecoration(
                                hintText: l10n.findReplaceHint,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                              onChanged: widget.controller.setReplaceText,
                              onSubmitted: (_) =>
                                  widget.controller.replaceCurrent(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const Key('find.replaceOne'),
                          onPressed: state.matches.isEmpty
                              ? null
                              : widget.controller.replaceCurrent,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            l10n.findReplaceOne,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          key: const Key('find.replaceAll'),
                          onPressed: state.matches.isEmpty
                              ? null
                              : widget.controller.replaceAll,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            l10n.findReplaceAll,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(
                          width: 32,
                        ), // Align with close button space
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
