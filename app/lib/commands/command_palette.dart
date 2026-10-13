// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../settings/providers.dart';
import 'command_registry.dart';
import 'fuzzy_matcher.dart';
import 'providers.dart';
import 'shortcut_codec.dart';
import 'tephra_command.dart';

Future<void> showCommandPalette(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => const _CommandPaletteDialog(),
  );
}

class _CommandPaletteDialog extends ConsumerStatefulWidget {
  const _CommandPaletteDialog();

  @override
  ConsumerState<_CommandPaletteDialog> createState() =>
      _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<_CommandPaletteDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event, List<TephraCommand> visibleCommands) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (visibleCommands.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % visibleCommands.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (visibleCommands.isEmpty) return;
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + visibleCommands.length) %
            visibleCommands.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (visibleCommands.isNotEmpty &&
          _selectedIndex >= 0 &&
          _selectedIndex < visibleCommands.length) {
        _runCommand(visibleCommands[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _runCommand(TephraCommand cmd) {
    final nav = Navigator.of(context);
    nav.pop();
    // Execute after dialog is dismissed
    cmd.run(ref, context);
    ref.read(appSettingsProvider.notifier).touchCommand(cmd.id);
  }

  List<TephraCommand> _filterCommands(
    CommandRegistry registry,
    List<String> recentCommands,
    AppLocalizations l10n,
    String query,
  ) {
    final available = registry.all.where((cmd) {
      if (!cmd.showInPalette) return false;
      return cmd.isAvailable?.call(ref) ?? true;
    }).toList();

    final q = query.trim();
    if (q.isEmpty) {
      final recents = <TephraCommand>[];
      final others = <TephraCommand>[];

      final recentSet = recentCommands.toSet();
      for (final id in recentCommands) {
        final match = available.where((c) => c.id == id).firstOrNull;
        if (match != null) recents.add(match);
      }
      for (final cmd in available) {
        if (!recentSet.contains(cmd.id)) {
          others.add(cmd);
        }
      }
      others.sort((a, b) => a.label(l10n).compareTo(b.label(l10n)));
      return [...recents, ...others];
    }

    final scored = <(TephraCommand, int)>[];
    for (final cmd in available) {
      final label = cmd.label(l10n);
      final s = FuzzyMatcher.score(q, label);
      if (s != null) {
        scored.add((cmd, s));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$1.label(l10n).compareTo(b.$1.label(l10n));
    });

    return scored.map((e) => e.$1).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final registry = ref.watch(commandRegistryProvider);
    final overrides = ref.watch(hotkeyOverridesProvider);
    final recentCommands = ref.watch(recentCommandsProvider);

    final visibleCommands = _filterCommands(
      registry,
      recentCommands,
      l10n,
      _controller.text,
    );

    if (_selectedIndex >= visibleCommands.length) {
      _selectedIndex = math.max(0, visibleCommands.length - 1);
    }

    final isWide = MediaQuery.sizeOf(context).width >= 840;

    final content = KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) => _onKey(event, visibleCommands),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('palette.query'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.palettePlaceholder,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {
                  _selectedIndex = 0;
                });
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleCommands.isEmpty
                ? Center(
                    child: Text(
                      l10n.paletteNoResults,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleCommands.length,
                    itemExtent: 48,
                    itemBuilder: (context, index) {
                      final cmd = visibleCommands[index];
                      final isSelected = index == _selectedIndex;
                      final label = cmd.label(l10n);
                      final effective = registry.effectiveShortcuts(
                        cmd.id,
                        overrides,
                      );
                      final ranges = _controller.text.trim().isEmpty
                          ? const <(int, int)>[]
                          : FuzzyMatcher.matchRanges(
                              _controller.text.trim(),
                              label,
                            );

                      return InkWell(
                        key: Key('palette.row.${cmd.id}'),
                        onTap: () => _runCommand(cmd),
                        child: Container(
                          height: 48,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              if (cmd.icon != null) ...[
                                Icon(cmd.icon, size: 20),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: _buildHighlightedText(
                                  context,
                                  label,
                                  ranges,
                                ),
                              ),
                              if (effective.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    for (final a in effective)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          formatShortcut(a),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Dialog(child: SizedBox(width: 560, height: 480, child: content));
    }

    return Dialog.fullscreen(child: SafeArea(child: content));
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    List<(int, int)> ranges,
  ) {
    if (ranges.isEmpty) {
      return Text(text, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final (start, end) in ranges) {
      if (start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastIndex = end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: spans,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
