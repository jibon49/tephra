// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';

class FirstSyncChoicePage extends ConsumerStatefulWidget {
  const FirstSyncChoicePage({required this.vaultId, super.key});

  final String vaultId;

  @override
  ConsumerState<FirstSyncChoicePage> createState() =>
      _FirstSyncChoicePageState();
}

class _FirstSyncChoicePageState extends ConsumerState<FirstSyncChoicePage> {
  String? _newFolderPath;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickNewFolder() async {
    final l10n = AppLocalizations.of(context);
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.syncSetupChooseFolder,
    );
    if (path != null) {
      setState(() => _newFolderPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncSetupControllerProvider(widget.vaultId));
    final controller = ref.read(
      syncSetupControllerProvider(widget.vaultId).notifier,
    );

    final isNewRemote = state.isCreatingNew;
    final isLocalEmpty = state.localStats.fileCount == 0;
    final sizeFormatted = _formatBytes(state.localStats.totalBytes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.syncSetupFirstSyncTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          RadioGroup<FirstSyncChoice>(
            groupValue: state.firstSyncChoice,
            onChanged: (val) {
              if (val != null) controller.setFirstSyncChoice(val);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNewRemote) ...[
                  RadioListTile<FirstSyncChoice>(
                    value: FirstSyncChoice.upload,
                    title: Text(
                      l10n.syncSetupUploadOption(
                        state.localStats.fileCount,
                        sizeFormatted,
                      ),
                    ),
                    subtitle: Text(l10n.syncSetupUploadSubtitle),
                  ),
                ] else if (isLocalEmpty) ...[
                  RadioListTile<FirstSyncChoice>(
                    value: FirstSyncChoice.download,
                    title: Text(l10n.syncSetupDownloadOption),
                    subtitle: Text(l10n.syncSetupDownloadSubtitle),
                  ),
                ] else ...[
                  RadioListTile<FirstSyncChoice>(
                    value: FirstSyncChoice.merge,
                    title: Text(l10n.syncSetupMergeOption),
                    subtitle: Text(l10n.syncSetupMergeExplain),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<FirstSyncChoice>(
                    value: FirstSyncChoice.downloadToNewFolder,
                    title: Text(l10n.syncSetupNewFolderOption),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.syncSetupNewFolderSubtitle),
                        if (state.firstSyncChoice ==
                            FirstSyncChoice.downloadToNewFolder) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _pickNewFolder,
                                child: Text(l10n.syncSetupChooseFolder),
                              ),
                              if (_newFolderPath != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _newFolderPath!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!kIsWeb && Platform.isAndroid) ...[
            const Divider(height: 32),
            SwitchListTile(
              value: state.backgroundSync,
              title: Text(l10n.syncSetupBackgroundSync),
              subtitle: Text(l10n.syncSetupBackgroundSyncSubtitle),
              onChanged: controller.setBackgroundSync,
            ),
            SwitchListTile(
              value: state.wifiOnly,
              title: Text(l10n.syncSetupWifiOnly),
              subtitle: Text(l10n.syncSetupWifiOnlySubtitle),
              onChanged: controller.setWifiOnly,
            ),
            SwitchListTile(
              value: state.mobileMode,
              title: Text(l10n.syncSetupMobileMode),
              subtitle: Text(l10n.syncSetupMobileModeSubtitle),
              onChanged: controller.setMobileMode,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => controller.startFirstSync(
              newFolderPath:
                  state.firstSyncChoice == FirstSyncChoice.downloadToNewFolder
                  ? _newFolderPath
                  : null,
            ),
            child: Text(l10n.syncSetupStartSync),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
