// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tephra/l10n/app_localizations.dart';
import 'package:tephra/settings/app_settings.dart';

/// List tile representing a recently opened vault.
class RecentVaultTile extends StatefulWidget {
  const RecentVaultTile({
    super.key,
    required this.vault,
    required this.index,
    required this.onOpen,
    required this.onRemove,
  });

  final RecentVault vault;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  State<RecentVaultTile> createState() => _RecentVaultTileState();
}

class _RecentVaultTileState extends State<RecentVaultTile> {
  bool _exists = true;

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  @override
  void didUpdateWidget(RecentVaultTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vault.path != widget.vault.path) {
      _checkExists();
    }
  }

  void _checkExists() {
    final dir = Directory(widget.vault.path);
    _exists = dir.existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formattedDate = DateFormat.yMMMd().format(widget.vault.lastOpened);

    return ListTile(
      key: Key('vaultPicker.recent.${widget.index}'),
      leading: Icon(
        Icons.folder_outlined,
        color: _exists ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Text(
        widget.vault.name,
        style: TextStyle(color: _exists ? null : theme.disabledColor),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.vault.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _exists ? null : theme.disabledColor),
          ),
          if (!_exists) ...[
            Text(
              l10n.vaultRecentMissing,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ] else ...[
            Text(
              formattedDate,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
      onTap: _exists ? widget.onOpen : null,
      trailing: PopupMenuButton<String>(
        key: Key('recentVault.menu.${widget.index}'),
        icon: const Icon(Icons.more_vert),
        onSelected: (val) {
          if (val == 'remove') {
            widget.onRemove();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'remove', child: Text(l10n.vaultRecentRemove)),
        ],
      ),
    );
  }
}
