// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/folder_picker.dart';
import '../../vault/providers.dart';
import '../../vault/vault_opener.dart';

/// Screen allowing the user to inspect a backup manifest, choose specific files or whole vault,
/// select a restore target (current vault vs fresh folder), and execute the restore safely.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({
    super.key,
    required this.vaultId,
    required this.manifest,
    this.initialPath,
    this.workerClient,
  });

  final String vaultId;
  final BackupManifest manifest;
  final String? initialPath;
  final SyncWorkerClient? workerClient;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

enum _TargetMode { intoVault, newFolder }

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final Set<String> _selectedPaths = {};
  _TargetMode _targetMode = _TargetMode.intoVault;
  String? _newFolderPath;

  bool _isRestoring = false;
  int _doneCount = 0;
  int _totalCount = 0;
  Map<String, dynamic>? _lastReport;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      _selectedPaths.add(widget.initialPath!);
    } else {
      // By default select all files
      _selectedPaths.addAll(widget.manifest.files.map((f) => f.path));
    }
  }

  SyncWorkerClient? get _client =>
      widget.workerClient ?? ref.read(syncWorkerClientProvider(widget.vaultId));

  void _toggleSelectAll() {
    setState(() {
      if (_selectedPaths.length == widget.manifest.files.length) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.clear();
        _selectedPaths.addAll(widget.manifest.files.map((f) => f.path));
      }
    });
  }

  Future<void> _pickDestinationFolder() async {
    final chosen = await pickFolderWithAccess(context, ref);
    if (chosen != null && mounted) {
      setState(() {
        _newFolderPath = chosen;
      });
    }
  }

  Future<void> _confirmAndRestore() async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedPaths.length;
    if (count == 0) return;

    if (_targetMode == _TargetMode.newFolder) {
      if (_newFolderPath == null || _newFolderPath!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restoreNewFolderMustBeEmpty)),
        );
        return;
      }
      final dir = Directory(_newFolderPath!);
      if (dir.existsSync() && dir.listSync().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restoreNewFolderMustBeEmpty)),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreTitle),
        content: Text(l10n.restoreConfirm(count)),
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

    setState(() {
      _isRestoring = true;
      _doneCount = 0;
      _totalCount = count;
      _lastReport = null;
    });

    try {
      final client = _client;
      final targetModeStr = _targetMode == _TargetMode.intoVault
          ? 'intoVault'
          : 'newFolder';

      Map<String, dynamic> reportMap;

      if (client != null) {
        reportMap = await client.restoreBackup({
          'stamp': widget.manifest.stamp,
          'selection': _selectedPaths.length == widget.manifest.files.length
              ? <String>[] // empty selection = whole vault
              : _selectedPaths.toList(),
          'targetMode': targetModeStr,
          'targetPath': _newFolderPath,
        });
      } else {
        // Fallback execution when worker client is null (e.g. test environments)
        final session = ref.read(vaultSessionProvider);
        if (session == null) {
          throw StateError('No vault session or sync worker available');
        }

        final store = await SyncStateStore.openMemory();
        final cipher = PlaintextObjectCipher();
        final provider = MemorySyncProvider();
        final blobStore = BlobStore(
          provider: provider,
          cipher: cipher,
          store: store,
        );

        final restoreService = RestoreService(
          provider: provider,
          cipher: cipher,
          blobStore: blobStore,
          fs: session.fs,
        );

        final req = RestoreRequest(
          stamp: widget.manifest.stamp,
          selection: _selectedPaths.length == widget.manifest.files.length
              ? const []
              : _selectedPaths.map((p) => VaultPath(p)).toList(),
          target: _targetMode == _TargetMode.intoVault
              ? RestoreTarget.intoVault
              : RestoreTarget.newFolder(_newFolderPath!),
        );

        final rep = await restoreService.restore(
          req,
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _doneCount = done;
                _totalCount = total;
              });
            }
          },
        );

        reportMap = {
          'restored': rep.restoredCount,
          'skipped': rep.skippedCount,
          'renamed': rep.renamedCount,
          'failed': rep.failedCount,
        };
      }

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _lastReport = reportMap;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<void> _openRestoredAsVault() async {
    if (_newFolderPath == null) return;
    try {
      final opener = ref.read(vaultOpenerProvider);
      await opener.open(_newFolderPath!);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to open vault: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.restoreTitle)),
      body: _isRestoring
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.restoreRunning(_doneCount, _totalCount),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Manifest info header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.backup_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Backup from ${widget.manifest.createdAt.toLocal().toString().split('.').first}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.manifest.deviceName} · ${widget.manifest.files.length} files · ${_formatBytes(widget.manifest.totalBytes)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_lastReport != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.restoreReport(
                                    _lastReport!['restored'] as int? ?? 0,
                                    _lastReport!['skipped'] as int? ?? 0,
                                    _lastReport!['renamed'] as int? ?? 0,
                                    _lastReport!['failed'] as int? ?? 0,
                                  ),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_targetMode == _TargetMode.newFolder &&
                              _newFolderPath != null) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _openRestoredAsVault,
                              icon: const Icon(Icons.folder_open),
                              label: Text(l10n.restoreOpenAsVault),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  'Target location',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: RadioGroup<_TargetMode>(
                    groupValue: _targetMode,
                    onChanged: (val) {
                      if (val != null) setState(() => _targetMode = val);
                    },
                    child: Column(
                      children: [
                        RadioListTile<_TargetMode>(
                          value: _TargetMode.intoVault,
                          title: Text(l10n.restoreTargetVault),
                        ),
                        RadioListTile<_TargetMode>(
                          value: _TargetMode.newFolder,
                          title: Text(l10n.restoreTargetNewFolder),
                          subtitle: _targetMode == _TargetMode.newFolder
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _pickDestinationFolder,
                                        icon: const Icon(Icons.folder_outlined),
                                        label: Text(
                                          _newFolderPath ?? 'Choose folder...',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.restoreNewFolderMustBeEmpty,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.restoreChooseFiles,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleSelectAll,
                      child: Text(
                        _selectedPaths.length == widget.manifest.files.length
                            ? 'Deselect all'
                            : l10n.restoreSelectAll,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.manifest.files.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = widget.manifest.files[index];
                      final isSelected = _selectedPaths.contains(file.path);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedPaths.add(file.path);
                            } else {
                              _selectedPaths.remove(file.path);
                            }
                          });
                        },
                        title: Text(file.path),
                        subtitle: Text(
                          '${_formatBytes(file.size)} · ${file.blobKeys.length} chunk${file.blobKeys.length == 1 ? '' : 's'}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _selectedPaths.isEmpty ? null : _confirmAndRestore,
                  icon: const Icon(Icons.restore),
                  label: Text(
                    'Restore ${_selectedPaths.length} file${_selectedPaths.length == 1 ? '' : 's'}',
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
}
