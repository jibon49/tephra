// © 2026 Tephra. All rights reserved.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../core/sync/sync_worker_client.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import '../../workspace/open_file.dart';
import '../diff/diff_view.dart';

/// Screen presenting the detailed side-by-side or stacked diff of a conflict
/// copy against the main file, and providing resolution actions.
class ConflictDetailScreen extends ConsumerStatefulWidget {
  const ConflictDetailScreen({
    super.key,
    required this.conflict,
    required this.vaultId,
  });

  final ConflictRecord conflict;
  final String vaultId;

  @override
  ConsumerState<ConflictDetailScreen> createState() =>
      _ConflictDetailScreenState();
}

class _ConflictDetailScreenState extends ConsumerState<ConflictDetailScreen> {
  bool _isLoading = true;
  bool _isResolving = false;
  bool _isEditMergeActive = false;

  String? _mainText;
  String? _copyText;
  Uint8List? _mainBytes;
  Uint8List? _copyBytes;
  VaultEntry? _mainStat;
  VaultEntry? _copyStat;

  late final TextEditingController _mergeTextController;

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

  static const _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'ico',
  };

  bool get _isBinary {
    if (widget.conflict.kind == 'binary') return true;
    final ext = widget.conflict.path.contains('.')
        ? widget.conflict.path.split('.').last.toLowerCase()
        : '';
    return !_textExtensions.contains(ext);
  }

  bool get _isImage {
    final ext = widget.conflict.path.contains('.')
        ? widget.conflict.path.split('.').last.toLowerCase()
        : '';
    return _imageExtensions.contains(ext);
  }

  @override
  void initState() {
    super.initState();
    _mergeTextController = TextEditingController();
    _loadFileContents();
  }

  @override
  void dispose() {
    _mergeTextController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContents() async {
    setState(() => _isLoading = true);
    final session = ref.read(vaultSessionProvider);
    if (session == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final fs = session.fs;
    final mainPath = VaultPath(widget.conflict.path);
    final copyPath = VaultPath(widget.conflict.copyPath);

    try {
      _mainStat = await fs.stat(mainPath);
      _copyStat = await fs.stat(copyPath);

      if (!_isBinary) {
        if (_mainStat != null) {
          final doc = await fs.readText(mainPath);
          _mainText = doc.text;
        } else {
          _mainText = '';
        }

        if (_copyStat != null) {
          final doc = await fs.readText(copyPath);
          _copyText = doc.text;
        } else {
          _copyText = '';
        }
        _mergeTextController.text = _mainText ?? '';
      } else {
        if (_mainStat != null) {
          _mainBytes = Uint8List.fromList(await fs.readBytes(mainPath));
        }
        if (_copyStat != null) {
          _copyBytes = Uint8List.fromList(await fs.readBytes(copyPath));
        }
      }
    } catch (_) {
      // In case of read error, keep whatever was read
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolve(
    ConflictResolution resolution, {
    String? mergedText,
  }) async {
    if (_isResolving || widget.conflict.id == null) return;
    setState(() => _isResolving = true);

    final client = ref.read(syncWorkerClientProvider(widget.vaultId));
    final l10n = AppLocalizations.of(context);

    try {
      if (client != null) {
        await client.resolveConflict(
          widget.conflict.id!,
          resolution,
          mergedText: mergedText,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.conflictResolved)));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to resolve: $e')));
        setState(() => _isResolving = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conflict.path),
        actions: [
          if (_isResolving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(context, theme, l10n),
                Expanded(
                  child: _isBinary
                      ? _buildBinaryBody(context, theme, l10n)
                      : _buildTextBody(context, theme, l10n),
                ),
                _buildActionBar(context, theme, l10n),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final timeStr = DateTime.fromMillisecondsSinceEpoch(widget.conflict.time)
        .toLocal()
        .toString()
        .split('.')
        .first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: Text(
                  widget.conflict.kind == 'case'
                      ? l10n.conflictKindCase
                      : (_isBinary
                            ? l10n.conflictKindBinary
                            : l10n.conflictKindText),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.conflictsFrom(widget.conflict.otherDevice, timeStr),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.conflictTheirVersion}: ${widget.conflict.path}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${l10n.conflictYourVersion}: ${widget.conflict.copyPath}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinaryBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        final theirCard = _buildBinaryVersionCard(
          context,
          theme,
          title: l10n.conflictTheirVersion,
          path: widget.conflict.path,
          stat: _mainStat,
          bytes: _mainBytes,
          buttonLabel: l10n.conflictOpenTheirFile,
        );

        final yourCard = _buildBinaryVersionCard(
          context,
          theme,
          title: l10n.conflictYourVersion,
          path: widget.conflict.copyPath,
          stat: _copyStat,
          bytes: _copyBytes,
          buttonLabel: l10n.conflictOpenYourFile,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.conflictBinaryExplain,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: theirCard),
                    const SizedBox(width: 16),
                    Expanded(child: yourCard),
                  ],
                )
              else ...[
                theirCard,
                const SizedBox(height: 16),
                yourCard,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBinaryVersionCard(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String path,
    required VaultEntry? stat,
    required Uint8List? bytes,
    required String buttonLabel,
  }) {
    final sizeStr = stat != null ? _formatBytes(stat.size) : 'Unknown';
    final dateStr = stat != null
        ? stat.modified.toLocal().toString().split('.').first
        : 'Unknown';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(path, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (_isImage && bytes != null && bytes.isNotEmpty) ...[
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(
                  Icons.data_usage,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text('Size: $sizeStr', style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text('Modified: $dateStr', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                openFile(ref, VaultPath(path));
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (_isEditMergeActive) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 840;

          final editorPane = Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.conflictEditMerge,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isResolving
                          ? null
                          : () => _resolve(
                              ConflictResolution.editMerge,
                              mergedText: _mergeTextController.text,
                            ),
                      icon: const Icon(Icons.save, size: 16),
                      label: Text(l10n.conflictSaveMerge),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _mergeTextController,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  child: DiffView(
                    oldText: _mainText ?? '',
                    newText: _copyText ?? '',
                    oldTitle: l10n.conflictTheirVersion,
                    newTitle: l10n.conflictYourVersion,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: editorPane),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(
                  flex: 1,
                  child: DiffView(
                    oldText: _mainText ?? '',
                    newText: _copyText ?? '',
                    oldTitle: l10n.conflictTheirVersion,
                    newTitle: l10n.conflictYourVersion,
                    showModeToggle: false,
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Expanded(flex: 1, child: editorPane),
              ],
            );
          }
        },
      );
    }

    return DiffView(
      oldText: _mainText ?? '',
      newText: _copyText ?? '',
      oldTitle: l10n.conflictTheirVersion,
      newTitle: l10n.conflictYourVersion,
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: _isResolving
                  ? null
                  : () => _resolve(ConflictResolution.keepMine),
              child: Text(l10n.conflictKeepMine),
            ),
            FilledButton.tonal(
              onPressed: _isResolving
                  ? null
                  : () => _resolve(ConflictResolution.keepTheirs),
              child: Text(l10n.conflictKeepTheirs),
            ),
            OutlinedButton(
              onPressed: _isResolving
                  ? null
                  : () => _resolve(ConflictResolution.keepBoth),
              child: Text(l10n.conflictKeepBoth),
            ),
            if (!_isBinary)
              OutlinedButton.icon(
                onPressed: _isResolving
                    ? null
                    : () {
                        setState(() {
                          _isEditMergeActive = !_isEditMergeActive;
                        });
                      },
                icon: Icon(
                  _isEditMergeActive ? Icons.close : Icons.edit_note,
                  size: 18,
                ),
                label: Text(
                  _isEditMergeActive ? 'Hide editor' : l10n.conflictEditMerge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
