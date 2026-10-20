// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import '../diff/diff_model.dart';
import '../diff/diff_view.dart';

/// Screen displaying the historical versions of [path], with a diff viewer against
/// the current note and restoration actions.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    required this.vaultId,
    required this.path,
    this.workerClient,
  });

  final String vaultId;
  final VaultPath path;
  final SyncWorkerClient? workerClient;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<VersionInfo> _versions = const [];
  VersionInfo? _selectedVersion;

  String _currentContent = '';
  String? _selectedContent;
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  SyncWorkerClient? get _client =>
      widget.workerClient ?? ref.read(syncWorkerClientProvider(widget.vaultId));

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = ref.read(vaultSessionProvider);
      if (session != null) {
        try {
          final currentBytes = await session.fs.readBytes(widget.path);
          _currentContent = utf8.decode(currentBytes, allowMalformed: true);
        } catch (_) {
          _currentContent = '';
        }
      }

      List<VersionInfo> loaded = const [];
      final client = _client;
      if (client != null) {
        loaded = await client.queryHistory(widget.path);
      } else if (session != null) {
        final lh = LocalHistory(session.fs);
        final vh = VersionHistory(
          localHistory: lh,
          remoteHistory: RemoteHistory(const []),
        );
        loaded = await vh.versions(widget.path);
      }

      if (mounted) {
        setState(() {
          _versions = loaded;
          _isLoading = false;
          if (loaded.isNotEmpty) {
            _selectVersion(loaded.first);
          } else {
            _selectedVersion = null;
            _selectedContent = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectVersion(VersionInfo version) async {
    setState(() {
      _selectedVersion = version;
      _isLoadingContent = true;
    });

    try {
      List<int>? bytes;
      final client = _client;
      if (client != null) {
        bytes = await client.loadVersion(version.ref);
      } else {
        final session = ref.read(vaultSessionProvider);
        if (session != null) {
          final lh = LocalHistory(session.fs);
          final vh = VersionHistory(
            localHistory: lh,
            remoteHistory: RemoteHistory(const []),
          );
          bytes = await vh.readVersion(version);
        }
      }

      if (mounted && _selectedVersion == version) {
        setState(() {
          _selectedContent = bytes != null
              ? utf8.decode(bytes, allowMalformed: true)
              : null;
          _isLoadingContent = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedVersion == version) {
        setState(() {
          _selectedContent = null;
          _isLoadingContent = false;
        });
      }
    }
  }

  Future<void> _restoreSelected() async {
    final version = _selectedVersion;
    if (version == null) return;

    final l10n = AppLocalizations.of(context);
    final timeStr = _formatTimestamp(version.time);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.historyRestore),
        content: Text(l10n.historyRestoreConfirm(timeStr)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.historyRestore),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final client = _client;
      if (client != null) {
        await client.restoreVersion(version.ref, widget.path);
      } else {
        final session = ref.read(vaultSessionProvider);
        if (session != null) {
          final lh = LocalHistory(session.fs);
          final vh = VersionHistory(
            localHistory: lh,
            remoteHistory: RemoteHistory(const []),
          );
          await vh.restoreVersion(
            version: version,
            path: widget.path,
            fs: session.fs,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.historyRestored)));
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore version: $e')),
        );
      }
    }
  }

  void _copySelected() {
    final content = _selectedContent;
    if (content == null) return;

    Clipboard.setData(ClipboardData(text: content));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.historyCopied)));
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fileName = widget.path.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle(fileName)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadHistory, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.historyEmpty,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        if (isDesktop) {
          return Row(
            children: [
              SizedBox(width: 320, child: _buildTimeline(context, l10n)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetailPane(context, l10n, isDesktop: true)),
            ],
          );
        } else {
          return Column(
            children: [
              SizedBox(height: 220, child: _buildTimeline(context, l10n)),
              const Divider(height: 1),
              Expanded(
                child: _buildDetailPane(context, l10n, isDesktop: false),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildTimeline(BuildContext context, AppLocalizations l10n) {
    return ListView.builder(
      itemCount: _versions.length,
      itemBuilder: (context, index) {
        final version = _versions[index];
        final isSelected = version == _selectedVersion;
        final timeStr = _formatTimestamp(version.time);
        final sizeStr = _formatSize(version.size);

        return ListTile(
          selected: isSelected,
          leading: Icon(
            version.origin == VersionOrigin.local
                ? Icons.save_outlined
                : Icons.cloud_outlined,
            size: 20,
          ),
          title: Text(
            timeStr,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  version.source == 'Local snapshot'
                      ? l10n.historyLocalSnapshot
                      : l10n.historyFromDevice(version.source),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (version.additionalSources.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '+${version.additionalSources.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (!version.isAvailable)
                Text(
                  l10n.historyUnavailable,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                )
              else if (sizeStr.isNotEmpty)
                Text(
                  sizeStr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          onTap: () => _selectVersion(version),
        );
      },
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isDesktop,
  }) {
    final version = _selectedVersion;
    if (version == null) {
      return Center(
        child: Text(
          l10n.historyEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (!version.isAvailable) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.historyUnavailable,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedText = _selectedContent ?? '';
    final timeStr = _formatTimestamp(version.time);

    return Column(
      children: [
        // Top action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${version.source} • $timeStr',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDesktop) ...[
                OutlinedButton.icon(
                  key: const Key('history_copy_button'),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(l10n.historyCopy),
                  onPressed: _copySelected,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('history_restore_button'),
                  icon: const Icon(Icons.restore, size: 16),
                  label: Text(l10n.historyRestore),
                  onPressed: _restoreSelected,
                ),
              ] else ...[
                IconButton(
                  key: const Key('history_copy_button'),
                  tooltip: l10n.historyCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: _copySelected,
                ),
                IconButton.filled(
                  key: const Key('history_restore_button'),
                  tooltip: l10n.historyRestore,
                  icon: const Icon(Icons.restore, size: 18),
                  onPressed: _restoreSelected,
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Diff against current
        Expanded(
          child: DiffView(
            oldText: selectedText,
            newText: _currentContent,
            oldTitle: '$timeStr (${version.source})',
            newTitle: l10n.historyCurrent,
            initialMode: isDesktop ? null : DiffDisplayMode.inline,
            showModeToggle: isDesktop,
          ),
        ),
      ],
    );
  }
}
