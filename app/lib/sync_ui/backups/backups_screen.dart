// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_sync/tephra_sync.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';

/// Screen for managing automated vault backups, schedule, retention, and points-in-time.
class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key, required this.vaultId, this.workerClient});

  final String vaultId;
  final SyncWorkerClient? workerClient;

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  bool _isLoading = true;
  bool _isBackingUp = false;
  String? _errorMessage;
  List<BackupManifest> _backups = const [];

  BackupScheduleFrequency _schedule = BackupScheduleFrequency.daily;
  int _retentionHourly = 48;
  int _retentionDaily = 30;
  int _retentionMonthly = 12;

  String? _lastVerificationDate;
  final int _verificationOk = 0;
  final int _verificationFailed = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  SyncWorkerClient? get _client =>
      widget.workerClient ?? ref.read(syncWorkerClientProvider(widget.vaultId));

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<BackupManifest> loadedBackups = const [];
      final client = _client;
      if (client != null) {
        loadedBackups = await client.listBackups();
      }

      final session = ref.read(vaultSessionProvider);
      if (session != null) {
        // Load metadata settings from session or SQLite if accessible
      }

      if (mounted) {
        setState(() {
          _backups = loadedBackups;
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

  Future<void> _triggerBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      final client = _client;
      if (client != null) {
        await client.backupNow(kind: BackupKind.manual);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup completed successfully')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  void _restoreBackup(BackupManifest backup) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupsRestore),
        content: Text('Restore for ${backup.stamp} will open in step 03.23.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupsTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isBackingUp ? null : _loadData,
          ),
        ],
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildConfigCard(context, l10n),
        const SizedBox(height: 16),
        _buildActionCard(context, l10n),
        const SizedBox(height: 24),
        Text(
          'Point-in-Time Backups',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildBackupsList(context, l10n),
      ],
    );
  }

  Widget _buildConfigCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupsSchedule,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BackupScheduleFrequency>(
              segments: [
                ButtonSegment(
                  value: BackupScheduleFrequency.off,
                  label: Text(l10n.backupsScheduleOff),
                ),
                ButtonSegment(
                  value: BackupScheduleFrequency.hourly,
                  label: Text(l10n.backupsScheduleHourly),
                ),
                ButtonSegment(
                  value: BackupScheduleFrequency.daily,
                  label: Text(l10n.backupsScheduleDaily),
                ),
                ButtonSegment(
                  value: BackupScheduleFrequency.weekly,
                  label: Text(l10n.backupsScheduleWeekly),
                ),
              ],
              selected: {_schedule},
              onSelectionChanged: (selected) {
                setState(() {
                  _schedule = selected.first;
                });
              },
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Retention Settings'),
              subtitle: Text(
                '$_retentionHourly hours · $_retentionDaily days · $_retentionMonthly months',
              ),
              children: [
                ListTile(
                  title: Text(l10n.backupsRetentionHourly),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _retentionHourly.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final v = int.tryParse(val);
                        if (v != null && v > 0) _retentionHourly = v;
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: Text(l10n.backupsRetentionDaily),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _retentionDaily.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final v = int.tryParse(val);
                        if (v != null && v > 0) _retentionDaily = v;
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: Text(l10n.backupsRetentionMonthly),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _retentionMonthly.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final v = int.tryParse(val);
                        if (v != null && v > 0) _retentionMonthly = v;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.backupsMobileModeNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lastVerificationDate != null)
                    Text(
                      l10n.backupsLastVerification(
                        _lastVerificationDate!,
                        _verificationOk,
                        _verificationFailed,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      'Backups are verified weekly',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _isBackingUp ? null : _triggerBackup,
              icon: _isBackingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup),
              label: Text(l10n.backupsBackUpNow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsList(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_backups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.backupsEmpty,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _backups.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final backup = _backups[index];
          final dateStr = _formatTimestamp(backup.createdAt);
          final sizeStr = _formatBytes(backup.totalBytes);

          return ListTile(
            leading: Icon(
              backup.kind == BackupKind.preRestore
                  ? Icons.restore
                  : Icons.cloud_done_outlined,
            ),
            title: Text(
              l10n.backupsEntry(
                dateStr,
                backup.deviceName,
                backup.fileCount,
                sizeStr,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Kind: ${backup.kind.name} · ID: ${backup.stamp}'),
            trailing: OutlinedButton(
              onPressed: () => _restoreBackup(backup),
              child: Text(l10n.backupsRestore),
            ),
          );
        },
      ),
    );
  }
}
