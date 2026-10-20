// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';

/// Shows the held deletions review UI as a bottom sheet on mobile or dialog on desktop.
Future<void> showHeldDeletesSheet(
  BuildContext context, {
  required String vaultId,
  required List<VaultPath> heldDeletes,
}) async {
  final width = MediaQuery.of(context).size.width;
  if (width >= 840) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
          child: HeldDeletesSheet(vaultId: vaultId, heldDeletes: heldDeletes),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: HeldDeletesSheet(vaultId: vaultId, heldDeletes: heldDeletes),
      ),
    );
  }
}

/// Widget letting users review and approve or keep files held by the large delete guard.
class HeldDeletesSheet extends ConsumerStatefulWidget {
  const HeldDeletesSheet({
    super.key,
    required this.vaultId,
    required this.heldDeletes,
  });

  final String vaultId;
  final List<VaultPath> heldDeletes;

  @override
  ConsumerState<HeldDeletesSheet> createState() => _HeldDeletesSheetState();
}

class _HeldDeletesSheetState extends ConsumerState<HeldDeletesSheet> {
  late final Map<String, bool> _deleteChoices;

  @override
  void initState() {
    super.initState();
    // Default to true (approve deletion)
    _deleteChoices = {for (final p in widget.heldDeletes) p.value: true};
  }

  Future<void> _submit(Map<String, DeleteDecision> decisions) async {
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    if (client != null) {
      await client.decideHeldDeletes(decisions);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _approveAll() {
    final decisions = {
      for (final p in widget.heldDeletes) p.value: DeleteDecision.approve,
    };
    _submit(decisions);
  }

  void _keepAll() {
    final decisions = {
      for (final p in widget.heldDeletes) p.value: DeleteDecision.keep,
    };
    _submit(decisions);
  }

  void _applySelection() {
    final decisions = {
      for (final entry in _deleteChoices.entries)
        entry.key: entry.value ? DeleteDecision.approve : DeleteDecision.keep,
    };
    _submit(decisions);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Group paths by parent folder
    final grouped = <String, List<VaultPath>>{};
    for (final p in widget.heldDeletes) {
      final parent = p.parent?.value ?? '/';
      grouped.putIfAbsent(parent, () => []).add(p);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: Colors.amber.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.syncHeldDeletesTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.syncHeldDeletesExplain(widget.heldDeletes.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: grouped.keys.length,
              itemBuilder: (context, idx) {
                final folder = grouped.keys.elementAt(idx);
                final files = grouped[folder]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            folder,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...files.map((p) {
                      final willDelete = _deleteChoices[p.value] ?? true;
                      return SwitchListTile(
                        dense: true,
                        secondary: Icon(
                          willDelete
                              ? Icons.delete_outline
                              : Icons.lock_outline,
                          color: willDelete
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          willDelete
                              ? l10n.syncHeldDeletesDelete
                              : l10n.syncHeldDeletesKeep,
                          style: TextStyle(
                            color: willDelete
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                        value: willDelete,
                        onChanged: (val) {
                          setState(() {
                            _deleteChoices[p.value] = val;
                          });
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('held_deletes_keep_all'),
                  onPressed: _keepAll,
                  child: Text(l10n.syncHeldDeletesKeep),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('held_deletes_apply_choices'),
                  onPressed: _applySelection,
                  child: Text(l10n.syncHeldDeletesApply),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('held_deletes_delete_all'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: _approveAll,
                  child: Text(l10n.syncHeldDeletesDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
