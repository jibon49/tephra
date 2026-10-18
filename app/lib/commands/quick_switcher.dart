// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_search/tephra_search.dart';

import '../core/providers.dart';

import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../workspace/open_file.dart';
import '../workspace/providers.dart';
import 'quick_switcher_items.dart';

final _logger = Logger('switcher');

Future<void> showQuickSwitcher(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => const _QuickSwitcherDialog(),
  );
}

class _QuickSwitcherDialog extends ConsumerStatefulWidget {
  const _QuickSwitcherDialog();

  @override
  ConsumerState<_QuickSwitcherDialog> createState() =>
      _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends ConsumerState<_QuickSwitcherDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event, List<SwitcherItem> visibleItems) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (visibleItems.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % visibleItems.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (visibleItems.isEmpty) return;
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + visibleItems.length) % visibleItems.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final isCtrl =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      final q = _controller.text.trim();

      if (isShift) {
        if (q.isNotEmpty) {
          _createAndOpen(q, newTab: false);
        }
      } else if (isCtrl) {
        if (visibleItems.isNotEmpty &&
            _selectedIndex >= 0 &&
            _selectedIndex < visibleItems.length) {
          _openItem(visibleItems[_selectedIndex], newTab: true);
        } else if (q.isNotEmpty) {
          _createAndOpen(q, newTab: true);
        }
      } else {
        if (visibleItems.isEmpty && q.isNotEmpty) {
          _createAndOpen(q, newTab: false);
        } else if (visibleItems.isNotEmpty &&
            _selectedIndex >= 0 &&
            _selectedIndex < visibleItems.length) {
          _openItem(visibleItems[_selectedIndex], newTab: false);
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _openItem(SwitcherItem item, {required bool newTab}) {
    Navigator.of(context).pop();
    if (item.isHeading && item.heading != null) {
      openFile(ref, item.path, subpath: '#${item.heading}', newTab: newTab);
    } else {
      openFile(ref, item.path, newTab: newTab);
    }
  }

  Future<void> _createAndOpen(String name, {required bool newTab}) async {
    Navigator.of(context).pop();
    final creator = ref.read(noteCreatorProvider);
    final activePath = ref.read(activeNotePathProvider);
    final path = await creator.createFromName(name, contextNote: activePath);
    if (mounted) {
      ref.read(focusEditorOnOpenProvider.notifier).set(true);
      openFile(ref, path, newTab: newTab);
    }
  }

  List<SwitcherItem> _rankItems(
    List<SwitcherItem> allItems,
    List<SwitcherItem> allHeadings,
    List<VaultPath> recents,
    String query,
  ) {
    final q = query.trim();
    final sw = Stopwatch()..start();

    if (q.isEmpty) {
      final itemMap = <VaultPath, SwitcherItem>{};
      for (final item in allItems) {
        if (!item.isAlias && !item.isAttachment && !item.isHeading) {
          itemMap[item.path] = item;
        }
      }
      final result = <SwitcherItem>[];
      for (final r in recents.take(50)) {
        final existing = itemMap[r];
        if (existing != null) {
          result.add(existing);
        } else if (r.isMarkdown) {
          result.add(
            SwitcherItem(
              path: r,
              primary: r.stem,
              secondary: r.parent?.value ?? '',
              primaryLower: r.stem.toLowerCase(),
              pathLower: r.value.toLowerCase(),
            ),
          );
        }
      }
      sw.stop();
      _logger.fine('perf switcher ${sw.elapsedMilliseconds} ms');
      return result;
    }

    if (q.startsWith('#')) {
      final headingQuery = q.substring(1).trim();
      final scored = <(SwitcherItem, int)>[];
      for (final item in allHeadings) {
        final s = headingQuery.isEmpty
            ? 0
            : FuzzyScorer.score(headingQuery, item.primary);
        if (s != null) {
          scored.add((item, s));
        }
      }
      scored.sort((a, b) {
        final cmp = b.$2.compareTo(a.$2);
        if (cmp != 0) return cmp;
        final lenCmp = a.$1.path.value.length.compareTo(b.$1.path.value.length);
        if (lenCmp != 0) return lenCmp;
        return a.$1.primary.compareTo(b.$1.primary);
      });
      final top50 = scored.take(50).map((e) => e.$1).toList();
      sw.stop();
      _logger.fine('perf switcher ${sw.elapsedMilliseconds} ms');
      return top50;
    }

    if (q.contains('#')) {
      final hashIdx = q.indexOf('#');
      final namePart = q.substring(0, hashIdx).trim();
      final headPart = q.substring(hashIdx + 1).trim();

      SwitcherItem? bestNote;
      var bestScore = -1000000;
      for (final item in allItems) {
        if (item.isAttachment || item.isHeading) continue;
        final primaryScore = FuzzyScorer.score(namePart, item.primary);
        int? pathScore;
        if (namePart.contains('/')) {
          final rawPath = FuzzyScorer.score(namePart, item.path.value);
          if (rawPath != null) pathScore = rawPath - 100;
        }
        int? matchScore;
        if (primaryScore != null && pathScore != null) {
          matchScore = math.max(primaryScore, pathScore);
        } else if (primaryScore != null) {
          matchScore = primaryScore;
        } else if (pathScore != null) {
          matchScore = pathScore;
        }
        if (matchScore == null) continue;

        final recentRank = recents.indexOf(item.path);
        final recentBoost = (recentRank >= 0 && recentRank < 10)
            ? math.max(0, 50 - 5 * recentRank)
            : 0;
        final total = matchScore + recentBoost;
        if (total > bestScore) {
          bestScore = total;
          bestNote = item;
        }
      }

      if (bestNote == null) {
        sw.stop();
        _logger.fine('perf switcher ${sw.elapsedMilliseconds} ms');
        return const [];
      }

      final noteHeadings = allHeadings.where((h) => h.path == bestNote!.path);
      final scored = <(SwitcherItem, int)>[];
      for (final h in noteHeadings) {
        final s = headPart.isEmpty ? 0 : FuzzyScorer.score(headPart, h.primary);
        if (s != null) {
          scored.add((h, s));
        }
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final top50 = scored.take(50).map((e) => e.$1).toList();
      sw.stop();
      _logger.fine('perf switcher ${sw.elapsedMilliseconds} ms');
      return top50;
    }

    final scored = <(SwitcherItem, int)>[];

    for (final item in allItems) {
      final primaryScore = FuzzyScorer.score(q, item.primary);
      int? pathScore;
      if (q.contains('/')) {
        final rawPath = FuzzyScorer.score(q, item.path.value);
        if (rawPath != null) {
          pathScore = rawPath - 100;
        }
      }

      int? matchScore;
      if (primaryScore != null && pathScore != null) {
        matchScore = math.max(primaryScore, pathScore);
      } else if (primaryScore != null) {
        matchScore = primaryScore;
      } else if (pathScore != null) {
        matchScore = pathScore;
      }

      if (matchScore == null) continue;

      final recentRank = recents.indexOf(item.path);
      final recentBoost = (recentRank >= 0 && recentRank < 10)
          ? math.max(0, 50 - 5 * recentRank)
          : 0;
      final totalScore = matchScore + recentBoost;
      scored.add((item, totalScore));
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      final lenCmp = a.$1.path.value.length.compareTo(b.$1.path.value.length);
      if (lenCmp != 0) return lenCmp;
      return a.$1.path.value.compareTo(b.$1.path.value);
    });

    final top50 = scored.take(50).map((e) => e.$1).toList();
    sw.stop();
    _logger.fine('perf switcher ${sw.elapsedMilliseconds} ms');
    return top50;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allItemsAsync = ref.watch(switcherItemsProvider);
    final allItems = allItemsAsync.value ?? const <SwitcherItem>[];
    final allHeadingsAsync = ref.watch(switcherHeadingsProvider);
    final allHeadings = allHeadingsAsync.value ?? const <SwitcherItem>[];
    final recents = ref.watch(recentFilesProvider);

    final q = _controller.text.trim();
    final visibleItems = _rankItems(allItems, allHeadings, recents, q);

    if (_selectedIndex >= visibleItems.length) {
      _selectedIndex = math.max(0, visibleItems.length - 1);
    }

    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final isPhone = !isWide;
    final canShowPhoneCreate =
        isPhone &&
        q.isNotEmpty &&
        !q.startsWith('#') &&
        !allItems.any(
          (i) =>
              i.primary.toLowerCase() == q.toLowerCase() ||
              i.path.value.toLowerCase() == q.toLowerCase(),
        );

    final content = KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) => _onKey(event, visibleItems),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('switcher.query'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.switcherPlaceholder,
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
            child:
                (allItemsAsync.error is IndexUnavailableException ||
                    ref.watch(noteIndexProvider).error
                        is IndexUnavailableException)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.indexUnavailableOnWeb,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                  )
                : (visibleItems.isEmpty && !canShowPhoneCreate
                      ? Center(
                          child: Text(
                            l10n.switcherNoResults,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              visibleItems.length +
                              (canShowPhoneCreate ? 1 : 0),
                          itemExtent: 48,
                          itemBuilder: (context, index) {
                            if (canShowPhoneCreate &&
                                index == visibleItems.length) {
                              return InkWell(
                                key: const Key('switcher.create'),
                                onTap: () => _createAndOpen(q, newTab: false),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        l10n.switcherCreate(q),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final item = visibleItems[index];
                            final isSelected = index == _selectedIndex;

                            final matchQuery = q.startsWith('#')
                                ? q.substring(1).trim()
                                : (q.contains('#')
                                      ? q.substring(q.indexOf('#') + 1).trim()
                                      : q);
                            final ranges = matchQuery.isEmpty
                                ? const <(int, int)>[]
                                : FuzzyScorer.matchRanges(
                                    matchQuery,
                                    item.primary,
                                  );

                            final IconData icon;
                            if (item.isHeading) {
                              icon = Icons.numbers_outlined;
                            } else if (item.isAlias) {
                              icon = Icons.shortcut_outlined;
                            } else if (item.isAttachment) {
                              icon = Icons.attach_file;
                            } else {
                              icon = Icons.description_outlined;
                            }

                            final Key rowKey;
                            if (item.isHeading) {
                              rowKey = Key(
                                'switcher.row.heading.${item.primary}',
                              );
                            } else if (item.isAlias) {
                              rowKey = Key(
                                'switcher.row.alias.${item.primary}',
                              );
                            } else {
                              rowKey = Key('switcher.row.${item.path.value}');
                            }

                            return InkWell(
                              key: rowKey,
                              onTap: () => _openItem(item, newTab: false),
                              child: Container(
                                height: 48,
                                color: isSelected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildHighlightedText(
                                            context,
                                            item.primary,
                                            ranges,
                                          ),
                                          if (item.secondary.isNotEmpty)
                                            Text(
                                              item.secondary,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .hintColor,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
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

    return Text.rich(
      TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }
}
