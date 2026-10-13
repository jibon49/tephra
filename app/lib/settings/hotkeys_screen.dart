// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_registry.dart';
import '../commands/fuzzy_matcher.dart';
import '../commands/hotkey_conflicts.dart';
import '../commands/providers.dart';
import '../commands/shortcut_codec.dart';
import '../commands/tephra_command.dart';
import '../l10n/app_localizations.dart';
import 'shortcut_recorder_dialog.dart';

class HotkeysScreen extends ConsumerStatefulWidget {
  const HotkeysScreen({super.key});

  @override
  ConsumerState<HotkeysScreen> createState() => _HotkeysScreenState();
}

class _HotkeysScreenState extends ConsumerState<HotkeysScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _recordShortcut(
    TephraCommand cmd,
    CommandRegistry registry,
    Map<String, List<SingleActivator>> overrides,
  ) async {
    final recorded = await showShortcutRecorderDialog(context);
    if (recorded == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final recordedStr = formatShortcut(recorded);
    final conflicts = conflictsFor(recordedStr, cmd.id, registry, overrides);

    if (conflicts.isNotEmpty) {
      final conflictNames = conflicts
          .map((id) {
            final c = registry.byId(id);
            return c != null ? c.label(l10n) : id;
          })
          .join(', ');

      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.hotkeyConflictTitle(conflictNames)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('keep'),
              child: Text(l10n.hotkeyKeepBoth),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('replace'),
              child: Text(l10n.hotkeyReplace),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel' || !mounted) return;

      if (choice == 'replace') {
        await ref.read(hotkeyOverridesProvider.notifier).update((m) {
          final copy = Map<String, List<SingleActivator>>.of(m);
          for (final conflictId in conflicts) {
            final list = registry.effectiveShortcuts(conflictId, copy);
            copy[conflictId] = list
                .where((s) => formatShortcut(s) != recordedStr)
                .toList();
          }
          final current = registry.effectiveShortcuts(cmd.id, copy);
          if (!current.any((s) => formatShortcut(s) == recordedStr)) {
            copy[cmd.id] = [...current, recorded];
          }
          return copy;
        });
        return;
      }
    }

    await ref.read(hotkeyOverridesProvider.notifier).update((m) {
      final copy = Map<String, List<SingleActivator>>.of(m);
      final current = registry.effectiveShortcuts(cmd.id, copy);
      if (!current.any((s) => formatShortcut(s) == recordedStr)) {
        copy[cmd.id] = [...current, recorded];
      }
      return copy;
    });
  }

  Future<void> _removeShortcut(
    TephraCommand cmd,
    SingleActivator activator,
    CommandRegistry registry,
    Map<String, List<SingleActivator>> overrides,
  ) async {
    final actStr = formatShortcut(activator);
    await ref.read(hotkeyOverridesProvider.notifier).update((m) {
      final copy = Map<String, List<SingleActivator>>.of(m);
      final current = registry.effectiveShortcuts(cmd.id, copy);
      copy[cmd.id] = current.where((s) => formatShortcut(s) != actStr).toList();
      return copy;
    });
  }

  Future<void> _resetCommand(TephraCommand cmd) async {
    await ref.read(hotkeyOverridesProvider.notifier).update((m) {
      final copy = Map<String, List<SingleActivator>>.of(m);
      copy.remove(cmd.id);
      return copy;
    });
  }

  Future<void> _resetAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hotkeysResetAll),
        content: const Text('Reset all hotkeys to their default shortcuts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.hotkeysResetAll),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(hotkeyOverridesProvider.notifier).resetAll();
    }
  }

  List<TephraCommand> _filterCommands(
    CommandRegistry registry,
    AppLocalizations l10n,
    String query,
  ) {
    final q = query.trim();
    if (q.isEmpty) return registry.all;

    return registry.all.where((cmd) {
      final label = cmd.label(l10n);
      return FuzzyMatcher.score(q, label) != null ||
          FuzzyMatcher.score(q, cmd.id) != null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final registry = ref.watch(commandRegistryProvider);
    final overrides = ref.watch(hotkeyOverridesProvider);
    final allConflicts = findHotkeyConflicts(registry, overrides);

    final commands = _filterCommands(registry, l10n, _searchController.text);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hotkeysTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.hotkeysSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: commands.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cmd = commands[index];
                final effective = registry.effectiveShortcuts(
                  cmd.id,
                  overrides,
                );
                final isCustomized = overrides.containsKey(cmd.id);

                final conflictShortcuts = <String>[];
                for (final a in effective) {
                  final str = formatShortcut(a);
                  final list = allConflicts[str];
                  if (list != null && list.length > 1) {
                    conflictShortcuts.add(str);
                  }
                }

                String? conflictTooltip;
                if (conflictShortcuts.isNotEmpty) {
                  final otherNames = <String>{};
                  for (final cs in conflictShortcuts) {
                    for (final otherId in allConflicts[cs]!) {
                      if (otherId != cmd.id) {
                        final c = registry.byId(otherId);
                        otherNames.add(c != null ? c.label(l10n) : otherId);
                      }
                    }
                  }
                  conflictTooltip = l10n.hotkeyConflictTitle(
                    otherNames.join(', '),
                  );
                }

                return ListTile(
                  title: Text(cmd.label(l10n)),
                  subtitle: Text(
                    cmd.id,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (conflictTooltip != null)
                        Tooltip(
                          message: conflictTooltip,
                          child: Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                        ),
                      for (final a in effective)
                        InputChip(
                          avatar: isCustomized
                              ? const Icon(Icons.circle, size: 8)
                              : null,
                          label: Text(formatShortcut(a)),
                          onDeleted: () =>
                              _removeShortcut(cmd, a, registry, overrides),
                        ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: l10n.hotkeysAdd,
                        onPressed: () =>
                            _recordShortcut(cmd, registry, overrides),
                      ),
                      if (isCustomized)
                        TextButton(
                          onPressed: () => _resetCommand(cmd),
                          child: Text(l10n.hotkeysReset),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetAll,
                child: Text(l10n.hotkeysResetAll),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
