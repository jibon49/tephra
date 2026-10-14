// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../settings/providers.dart';
import 'new_note_location.dart';
import 'providers.dart';

final class NoteCreator {
  NoteCreator(this.ref);

  final Ref ref;

  Future<VaultPath> createFromName(
    String name, {
    VaultPath? contextNote,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const InvalidPathException('Note name cannot be empty');
    }

    final VaultPath targetPath;
    if (trimmed.contains('/') || trimmed.contains(r'\')) {
      final normalized = trimmed.replaceAll(r'\', '/');
      final lastSlash = normalized.lastIndexOf('/');
      final lastSeg = normalized.substring(lastSlash + 1);
      final withExt = lastSeg.toLowerCase().endsWith('.md')
          ? normalized
          : '$normalized.md';
      targetPath = VaultPath(withExt);
    } else {
      final settings = ref.read(vaultSettingsProvider);
      final folder = resolveNewNoteFolder(settings, contextNote);
      final withExt = trimmed.toLowerCase().endsWith('.md')
          ? trimmed
          : '$trimmed.md';
      targetPath = folder.isRoot ? VaultPath(withExt) : folder.join(withExt);
    }

    final fs = ref.read(vaultFsProvider);
    final stat = await fs.stat(targetPath);
    if (stat != null) {
      return targetPath;
    }

    await fs.writeText(targetPath, const TextDocument(text: ''));
    ref.read(vaultRevisionProvider.notifier).bump();
    return targetPath;
  }

  Future<VaultPath> createUntitled({
    VaultPath? folder,
    VaultPath? contextNote,
  }) async {
    final settings = ref.read(vaultSettingsProvider);
    final effectiveFolder =
        folder ?? resolveNewNoteFolder(settings, contextNote);
    final fs = ref.read(vaultFsProvider);

    var counter = 0;
    while (true) {
      final stem = counter == 0 ? 'Untitled' : 'Untitled $counter';
      final fileName = '$stem.md';
      final candidate = effectiveFolder.isRoot
          ? VaultPath(fileName)
          : effectiveFolder.join(fileName);
      final stat = await fs.stat(candidate);
      if (stat == null) {
        await fs.writeText(candidate, const TextDocument(text: ''));
        ref.read(vaultRevisionProvider.notifier).bump();
        return candidate;
      }
      counter++;
    }
  }
}
