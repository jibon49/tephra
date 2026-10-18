// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/providers.dart';
import '../editor/providers.dart';
import '../explorer/providers.dart';
import '../l10n/app_localizations.dart';
import '../vault/new_note_location.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';

/// Navigation coordinator for opening, following, and auto-creating internal links.
final class LinkNavigator {
  LinkNavigator(this.ref);

  final Ref ref;

  DateTime? _lastCreateTime;
  VaultPath? _lastCreatePath;

  AppLocalizations? get _l10n {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      final context = key.currentContext;
      if (context != null) {
        return AppLocalizations.of(context);
      }
    } catch (_) {}
    return null;
  }

  void _showSnackBar(String text) {
    try {
      final key = ref.read(scaffoldMessengerKeyProvider);
      key.currentState?.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {}
  }

  /// Opens the note at [target] from the context of [from], resolving headings/blocks,
  /// or creating the note if it does not exist.
  Future<void> open({
    required VaultPath from,
    required String target,
    String? heading,
    String? blockRef,
    bool newTab = false,
  }) async {
    final l10n = _l10n;
    final index = await ref.read(noteIndexProvider.future);

    // 1. Resolve against index
    final path = await index.resolveLink(target, from: from);

    // 2. If resolved, navigate to target and scroll/reveal heading or block
    if (path != null) {
      int? targetOffset;
      if (heading != null) {
        final headings = await index.headings(path);
        final h = findHeading(headings, heading);
        if (h != null) {
          targetOffset = h.start;
        } else {
          _showSnackBar(
            l10n?.linkHeadingNotFound ?? 'Heading or block not found',
          );
        }
      } else if (blockRef != null) {
        final blocks = await index.blocks(path);
        final b = findBlock(blocks, blockRef);
        if (b != null) {
          targetOffset = b.start;
        } else {
          _showSnackBar(
            l10n?.linkHeadingNotFound ?? 'Heading or block not found',
          );
        }
      }

      if (targetOffset != null || heading != null || blockRef != null) {
        ref
            .read(pendingJumpProvider.notifier)
            .set(
              PendingJump(
                path: path,
                heading: heading,
                blockRef: blockRef,
                offset: targetOffset,
              ),
            );
      }

      ref.read(workspaceProvider.notifier).openPath(path, newTab: newTab);

      if (targetOffset != null) {
        final controller = ref.read(editorRegistryProvider).controllerFor(path);
        if (controller != null) {
          controller.select(targetOffset);
          controller.revealOffset(targetOffset);
        }
      }
      return;
    }

    // 3. Unresolved: check empty or non-md extension
    final trimmed = target.trim();
    if (trimmed.isEmpty) return;

    final lastSlash = trimmed.lastIndexOf('/');
    final lastBackslash = trimmed.lastIndexOf(r'\');
    final sep = lastSlash > lastBackslash ? lastSlash : lastBackslash;
    final lastSegment = sep != -1 ? trimmed.substring(sep + 1) : trimmed;
    final dot = lastSegment.lastIndexOf('.');
    final ext = (dot > 0) ? lastSegment.substring(dot + 1).toLowerCase() : '';
    if (ext.isNotEmpty && ext != 'md') {
      _showSnackBar(
        l10n?.linkTargetFileMissing(lastSegment) ??
            '"$lastSegment" doesn\'t exist in this vault',
      );
      return;
    }

    // 4. Create the note
    final VaultPath newPath;
    if (target.contains('/') || target.contains(r'\')) {
      final normalizedTarget = target.replaceAll(r'\', '/');
      final pathString = normalizedTarget.toLowerCase().endsWith('.md')
          ? normalizedTarget
          : '$normalizedTarget.md';
      try {
        newPath = VaultPath(pathString);
      } on InvalidPathException {
        _showSnackBar(l10n?.linkInvalidTarget ?? 'Invalid link target');
        return;
      }
    } else {
      final settings = ref.read(vaultSettingsProvider);
      final folder = resolveNewNoteFolder(settings, from);
      final fileName = target.toLowerCase().endsWith('.md')
          ? target
          : '$target.md';
      try {
        newPath = folder.join(fileName);
      } on InvalidPathException {
        _showSnackBar(l10n?.linkInvalidTarget ?? 'Invalid link target');
        return;
      }
    }

    // Debounce duplicate create clicks within 500ms
    final now = DateTime.now();
    if (_lastCreatePath == newPath &&
        _lastCreateTime != null &&
        now.difference(_lastCreateTime!).inMilliseconds < 500) {
      return;
    }
    _lastCreatePath = newPath;
    _lastCreateTime = now;

    final fs = ref.read(vaultFsProvider);
    if ((await fs.stat(newPath)) != null) {
      ref.read(workspaceProvider.notifier).openPath(newPath, newTab: newTab);
    } else {
      await fs.writeText(newPath, const TextDocument(text: ''));
      ref.read(workspaceProvider.notifier).openPath(newPath, newTab: newTab);
    }
  }
}
