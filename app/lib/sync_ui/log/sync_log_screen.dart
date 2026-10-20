// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/open_file.dart';
import 'sync_log_text.dart';

enum _LogFilter { all, changes, problems }

/// Screen showing the historical synchronization log with filters and copy option.
class SyncLogScreen extends ConsumerStatefulWidget {
  const SyncLogScreen({super.key, required this.vaultId});

  final String vaultId;

  @override
  ConsumerState<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends ConsumerState<SyncLogScreen> {
  _LogFilter _filter = _LogFilter.all;
  List<SyncLogEntry> _entries = [];
  bool _loading = true;
  StreamSubscription<SyncLogEntry>? _logSub;

  @override
  void initState() {
    super.initState();
    _loadInitialLog();
    _listenToLiveLog();
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialLog() async {
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    if (client != null) {
      try {
        final logs = await client.queryLog(limit: 200);
        if (mounted) {
          setState(() {
            _entries = logs;
            _loading = false;
          });
        }
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _listenToLiveLog() {
    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    if (client != null) {
      _logSub = client.logStream.listen((entry) {
        if (mounted) {
          setState(() {
            _entries = [entry, ..._entries];
          });
        }
      });
    }
  }

  List<SyncLogEntry> get _filteredEntries {
    switch (_filter) {
      case _LogFilter.all:
        return _entries;
      case _LogFilter.changes:
        return _entries.where(SyncLogText.isChange).toList();
      case _LogFilter.problems:
        return _entries.where(SyncLogText.isProblem).toList();
    }
  }

  void _copyLog(AppLocalizations l10n) {
    final filtered = _filteredEntries;
    final buffer = StringBuffer();
    for (final entry in filtered) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        entry.time,
        isUtc: true,
      ).toLocal();
      final timeStr =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      final desc = SyncLogText.describe(entry, l10n);
      buffer.writeln('[$timeStr] [${entry.level.toUpperCase()}] $desc');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.syncLogCopied)));
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(entryDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  IconData _iconForEntry(SyncLogEntry entry) {
    switch (entry.kind) {
      case 'uploaded':
        return Icons.cloud_upload_outlined;
      case 'downloaded':
        return Icons.cloud_download_outlined;
      case 'merged':
        return Icons.call_merge;
      case 'conflictCopy':
        return Icons.content_copy;
      case 'deletedLocal':
      case 'deletedRemote':
        return Icons.delete_outline;
      case 'renamedLocal':
      case 'renamedRemote':
      case 'caseConflictRenamed':
      case 'invalidNameRenamed':
        return Icons.drive_file_rename_outline;
      case 'heldDeletes':
      case 'keptEditedFileDeletedElsewhere':
      case 'restoredDeletedFileChangedElsewhere':
        return Icons.shield_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return entry.level == 'error'
            ? Icons.error_outline
            : entry.level == 'warning'
            ? Icons.warning_amber_rounded
            : Icons.info_outline;
    }
  }

  Color _iconColor(BuildContext context, SyncLogEntry entry) {
    final theme = Theme.of(context);
    if (entry.level == 'error' || entry.kind == 'error') {
      return theme.colorScheme.error;
    }
    if (entry.level == 'warning' ||
        entry.kind == 'caseConflictRenamed' ||
        entry.kind == 'invalidNameRenamed' ||
        entry.kind == 'heldDeletes') {
      return Colors.amber.shade700;
    }
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filteredEntries;

    // Group filtered items by date
    final groups = <String, List<SyncLogEntry>>{};
    for (final entry in filtered) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        entry.time,
        isUtc: true,
      ).toLocal();
      final header = _formatDayHeader(dt);
      groups.putIfAbsent(header, () => []).add(entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncLogTitle),
        actions: [
          TextButton.icon(
            key: const Key('sync_log_copy_button'),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.syncLogCopy),
            onPressed: filtered.isEmpty ? null : () => _copyLog(l10n),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  key: const Key('sync_log_filter_all'),
                  label: Text(l10n.syncLogFilterAll),
                  selected: _filter == _LogFilter.all,
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = _LogFilter.all);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  key: const Key('sync_log_filter_changes'),
                  label: Text(l10n.syncLogFilterChanges),
                  selected: _filter == _LogFilter.changes,
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = _LogFilter.changes);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  key: const Key('sync_log_filter_problems'),
                  label: Text(l10n.syncLogFilterProblems),
                  selected: _filter == _LogFilter.problems,
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = _LogFilter.problems);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      l10n.syncLogEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: groups.keys.length,
                    itemBuilder: (context, groupIdx) {
                      final dayKey = groups.keys.elementAt(groupIdx);
                      final dayEntries = groups[dayKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                            child: Text(
                              dayKey,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          ...dayEntries.map((entry) {
                            final dt = DateTime.fromMillisecondsSinceEpoch(
                              entry.time,
                              isUtc: true,
                            ).toLocal();
                            final timeStr =
                                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            final hasPath =
                                entry.path != null && entry.path!.isNotEmpty;

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                _iconForEntry(entry),
                                color: _iconColor(context, entry),
                                size: 20,
                              ),
                              title: Text(
                                SyncLogText.describe(entry, l10n),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                timeStr,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                              ),
                              trailing: hasPath
                                  ? const Icon(Icons.chevron_right, size: 16)
                                  : null,
                              onTap: hasPath
                                  ? () {
                                      openFile(ref, VaultPath(entry.path!));
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  : null,
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
