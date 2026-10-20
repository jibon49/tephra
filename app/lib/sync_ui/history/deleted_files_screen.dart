// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import 'history_screen.dart';

/// Screen listing recently deleted files with restoration and history actions.
class DeletedFilesScreen extends ConsumerStatefulWidget {
  const DeletedFilesScreen({
    super.key,
    required this.vaultId,
    this.workerClient,
  });

  final String vaultId;
  final SyncWorkerClient? workerClient;

  @override
  ConsumerState<DeletedFilesScreen> createState() => _DeletedFilesScreenState();
}

class _DeletedFilesScreenState extends ConsumerState<DeletedFilesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<RecentlyDeletedFile> _deletedFiles = const [];

  @override
  void initState() {
    super.initState();
    _loadDeleted();
  }

  SyncWorkerClient? get _client =>
      widget.workerClient ?? ref.read(syncWorkerClientProvider(widget.vaultId));

  Future<void> _loadDeleted() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<RecentlyDeletedFile> loaded = const [];
      final client = _client;
      if (client != null) {
        loaded = await client.queryDeleted();
      } else {
        final session = ref.read(vaultSessionProvider);
        if (session != null) {
          final lh = LocalHistory(session.fs);
          final vh = VersionHistory(
            localHistory: lh,
            remoteHistory: RemoteHistory(const []),
          );
          loaded = await vh.recentlyDeleted(fs: session.fs);
        }
      }

      if (mounted) {
        setState(() {
          _deletedFiles = loaded;
          _isLoading = false;
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

  Future<void> _restoreFile(RecentlyDeletedFile deleted) async {
    final l10n = AppLocalizations.of(context);
    try {
      String restoredPathStr = deleted.path.value;
      final client = _client;
      if (client != null) {
        restoredPathStr = await client.restoreDeleted(deleted);
      } else {
        final session = ref.read(vaultSessionProvider);
        if (session != null) {
          final lh = LocalHistory(session.fs);
          final vh = VersionHistory(
            localHistory: lh,
            remoteHistory: RemoteHistory(const []),
          );
          final target = await vh.restoreDeletedFile(
            deleted: deleted,
            fs: session.fs,
          );
          restoredPathStr = target.value;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletedRestoredAs(restoredPathStr))),
        );
        await _loadDeleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to restore file: $e')));
      }
    }
  }

  void _openHistory(RecentlyDeletedFile deleted) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          vaultId: widget.vaultId,
          path: deleted.path,
          workerClient: widget.workerClient,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deletedTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeleted,
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
              FilledButton(onPressed: _loadDeleted, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_deletedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.deletedEmpty,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _deletedFiles.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _deletedFiles[index];
        final timeStr = _formatTimestamp(item.deletedTime);

        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(
            item.path.value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l10n.deletedBy(item.deletingDevice, timeStr)),
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _openHistory(item),
                child: Text(l10n.deletedOpenHistory),
              ),
              FilledButton.tonal(
                onPressed: () => _restoreFile(item),
                child: Text(l10n.deletedRestore),
              ),
            ],
          ),
        );
      },
    );
  }
}
