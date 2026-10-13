// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../settings/vault_settings.dart';

VaultPath resolveNewNoteFolder(VaultSettings settings, VaultPath? contextNote) {
  switch (settings.newFileLocation) {
    case 'current':
      return contextNote?.parent ?? VaultPath.root;
    case 'folder':
      if (settings.newFileFolder.isEmpty) return VaultPath.root;
      return VaultPath.tryParse(settings.newFileFolder) ?? VaultPath.root;
    case 'root':
    default:
      return VaultPath.root;
  }
}
