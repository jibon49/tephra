// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../editor/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'providers.dart';

enum BacklinksSortMode { nameAsc, nameDesc, modifiedNew }

/// Backlinks pane displaying linked and unlinked mentions of the active note.
class BacklinksPane extends ConsumerStatefulWidget {
  const BacklinksPane({super.key});

  @override
  ConsumerState<BacklinksPane> createState() => _BacklinksPaneState();
}

class _BacklinksPaneState extends ConsumerState<BacklinksPane> {
  bool _linkedExpanded = true;
  bool _unlinkedExpanded = false;
  BacklinksSortMode _sortMode = BacklinksSortMode.nameAsc;
  final Set<VaultPath> _collapsedGroups = {};

  void _collapseAll() {
    setState(() {
      _linkedExpanded = false;
      _unlinkedExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePath = ref.watch(activeNotePathProvider);
    final l10n = AppLocalizations.of(context);

    if (activePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.noActiveNote,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    final backlinksAsync = ref.watch(backlinksProvider(activePath));

    return Column(
      children: [
        _buildToolbar(context, l10n),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              backlinksAsync.when(
                data: (links) =>
                    _buildLinkedSection(context, activePath, links, l10n),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $err'),
                ),
              ),
              const SizedBox(height: 8),
              _buildUnlinkedSection(context, activePath, l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          PopupMenuButton<BacklinksSortMode>(
            tooltip: l10n.explorerSort,
            icon: const Icon(Icons.sort, size: 20),
            initialValue: _sortMode,
            onSelected: (mode) {
              setState(() => _sortMode = mode);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: BacklinksSortMode.nameAsc,
                child: Text(l10n.sortAlphabeticalAsc),
              ),
              PopupMenuItem(
                value: BacklinksSortMode.nameDesc,
                child: Text(l10n.sortAlphabeticalDesc),
              ),
              PopupMenuItem(
                value: BacklinksSortMode.modifiedNew,
                child: Text(l10n.sortModifiedNew),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.collapseAllAction,
            icon: const Icon(Icons.unfold_less, size: 20),
            onPressed: _collapseAll,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLinkedSection(
    BuildContext context,
    VaultPath activePath,
    List<LinkRecord> links,
    AppLocalizations l10n,
  ) {
    final groups = <VaultPath, List<LinkRecord>>{};
    for (final l in links) {
      groups.putIfAbsent(l.source, () => []).add(l);
    }

    final sortedKeys = groups.keys.toList();
    if (_sortMode == BacklinksSortMode.nameAsc) {
      sortedKeys.sort(
        (a, b) => a.stem.toLowerCase().compareTo(b.stem.toLowerCase()),
      );
    } else if (_sortMode == BacklinksSortMode.nameDesc) {
      sortedKeys.sort(
        (a, b) => b.stem.toLowerCase().compareTo(a.stem.toLowerCase()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() => _linkedExpanded = !_linkedExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _linkedExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.linkedMentionsTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(links.length),
              ],
            ),
          ),
        ),
        if (_linkedExpanded) ...[
          for (final source in sortedKeys)
            _buildSourceGroup(context, source, groups[source]!),
        ],
      ],
    );
  }

  Widget _buildSourceGroup(
    BuildContext context,
    VaultPath source,
    List<LinkRecord> links,
  ) {
    final isCollapsed = _collapsedGroups.contains(source);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            ref.read(workspaceProvider.notifier).openPath(source);
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 16,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isCollapsed) {
                        _collapsedGroups.remove(source);
                      } else {
                        _collapsedGroups.add(source);
                      }
                    });
                  },
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    source.stem,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildBadge(links.length),
              ],
            ),
          ),
        ),
        if (!isCollapsed) ...[
          for (final link in links) _buildLinkTile(context, source, link),
        ],
      ],
    );
  }

  Widget _buildLinkTile(
    BuildContext context,
    VaultPath source,
    LinkRecord link,
  ) {
    return FutureBuilder<String>(
      future: _readSourceText(source),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final text = snapshot.data!;
        final (snippetText, boldStart, boldEnd) = _computeContext(text, link);

        return InkWell(
          onTap: () async {
            ref.read(workspaceProvider.notifier).openPath(source);
            final controller = ref
                .read(editorRegistryProvider)
                .controllerFor(source);
            controller?.select(link.start, link.end);
            controller?.revealOffset(link.start);
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 48,
              right: 16,
              top: 4,
              bottom: 4,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withAlpha(80),
                borderRadius: BorderRadius.circular(4),
              ),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  children: [
                    if (boldStart > 0)
                      TextSpan(text: snippetText.substring(0, boldStart)),
                    TextSpan(
                      text: snippetText.substring(boldStart, boldEnd),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (boldEnd < snippetText.length)
                      TextSpan(text: snippetText.substring(boldEnd)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlinkedSection(
    BuildContext context,
    VaultPath activePath,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() => _unlinkedExpanded = !_unlinkedExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _unlinkedExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.unlinkedMentionsTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_unlinkedExpanded) _buildUnlinkedContent(context, activePath, l10n),
      ],
    );
  }

  Widget _buildUnlinkedContent(
    BuildContext context,
    VaultPath activePath,
    AppLocalizations l10n,
  ) {
    final mentionsAsync = ref.watch(unlinkedMentionsProvider(activePath));

    return mentionsAsync.when(
      data: (mentions) {
        if (mentions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Text(
              'No unlinked mentions',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          );
        }

        final isPhone = MediaQuery.of(context).size.width < 840;

        return Column(
          children: [
            for (final m in mentions)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withAlpha(80),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.source.stem,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            height: isPhone ? 48 : 32,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: () async {
                                await ref
                                    .read(unlinkedMentionLinkerProvider)
                                    .link(m, activePath);
                              },
                              child: Text(l10n.linkMentionAction),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          ref
                              .read(workspaceProvider.notifier)
                              .openPath(m.source);
                          final controller = ref
                              .read(editorRegistryProvider)
                              .controllerFor(m.source);
                          controller?.select(m.start, m.end);
                          controller?.revealOffset(m.start);
                        },
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: [
                              if (m.snippetStart > 0)
                                TextSpan(
                                  text: m.snippet.substring(0, m.snippetStart),
                                ),
                              TextSpan(
                                text: m.snippet.substring(
                                  m.snippetStart,
                                  m.snippetEnd,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              if (m.snippetEnd < m.snippet.length)
                                TextSpan(
                                  text: m.snippet.substring(m.snippetEnd),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $err'),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Future<String> _readSourceText(VaultPath source) async {
    final controller = ref.read(editorRegistryProvider).controllerFor(source);
    if (controller != null) return controller.text;
    final fs = ref.read(vaultFsProvider);
    final doc = await fs.readText(source);
    return doc.text;
  }

  (String, int, int) _computeContext(String text, LinkRecord link) {
    if (text.isEmpty) return ('', 0, 0);

    final lines = LineIndex(text);
    final startOffset = link.start.clamp(0, text.length);
    final l = lines.lineOf(startOffset);

    final startLine = (l > 0) ? l - 1 : 0;
    final endLine = (l + 1 < lines.lineCount) ? l + 1 : lines.lineCount - 1;

    final contextStart = lines.lineStart(startLine);
    final contextEnd = lines.lineEnd(endLine);

    final contextText = text.substring(contextStart, contextEnd);
    final boldStart = (link.start - contextStart).clamp(0, contextText.length);
    final boldEnd = (link.end - contextStart).clamp(
      boldStart,
      contextText.length,
    );

    return (contextText, boldStart, boldEnd);
  }
}
