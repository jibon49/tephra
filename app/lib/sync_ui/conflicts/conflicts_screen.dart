// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import 'conflict_detail_screen.dart';

/// Screen listing all unresolved file synchronization conflicts.
class ConflictsScreen extends ConsumerStatefulWidget {
  const ConflictsScreen({super.key, required this.vaultId});

  final String vaultId;

  @override
  ConsumerState<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends ConsumerState<ConflictsScreen> {
  bool _isLoading = true;
  List<ConflictRecord> _conflicts = [];

  static const _textExtensions = {
    'md',
    'txt',
    'canvas',
    'json',
    'base',
    'csv',
    'tsv',
    'html',
    'css',
    'js',
    'dart',
    'yaml',
    'yml',
    'xml',
    'arb',
    'log',
  };

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() => _isLoading = true);
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    if (client == null) {
      if (mounted) {
        setState(() {
          _conflicts = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final list = await client.queryConflicts();
      if (mounted) {
        setState(() {
          _conflicts = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _conflicts = [];
          _isLoading = false;
        });
      }
    }
  }

  bool _isBinary(ConflictRecord c) {
    if (c.kind == 'binary') return true;
    final ext = c.path.contains('.')
        ? c.path.split('.').last.toLowerCase()
        : '';
    return !_textExtensions.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conflictsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConflicts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conflicts.isEmpty
          ? _buildEmptyState(context, theme, l10n)
          : _buildConflictsList(context, theme, l10n),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.conflictsEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictsList(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _conflicts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conflict = _conflicts[index];
        final isBinary = _isBinary(conflict);
        final timeStr = DateTime.fromMillisecondsSinceEpoch(conflict.time)
            .toLocal()
            .toString()
            .split('.')
            .first;

        final IconData leadingIcon;
        final String kindLabel;
        if (conflict.kind == 'case') {
          leadingIcon = Icons.text_fields_outlined;
          kindLabel = l10n.conflictKindCase;
        } else if (isBinary) {
          leadingIcon = Icons.insert_drive_file_outlined;
          kindLabel = l10n.conflictKindBinary;
        } else {
          leadingIcon = Icons.description_outlined;
          kindLabel = l10n.conflictKindText;
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final resolved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ConflictDetailScreen(
                    conflict: conflict,
                    vaultId: widget.vaultId,
                  ),
                ),
              );
              if (resolved == true) {
                await _loadConflicts();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      leadingIcon,
                      color: theme.colorScheme.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflict.path,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conflict.copyPath,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.conflictsFrom(conflict.otherDevice, timeStr),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      kindLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
