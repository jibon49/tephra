// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../settings/vault_settings.dart';
import '../new_note_location.dart';
import 'exceptions.dart';

/// Service creating unique notes (Zettelkasten-style prefixer).
final class UniqueNoteService {
  UniqueNoteService({
    required this.fs,
    required dynamic index,
    required this.getSettings,
    required this.clock,
    required this.openNote,
    this.showSnackbar,
  }) : _getIndex = (index is FutureOr<NoteIndex> Function()
           ? index
           : () => index as NoteIndex);

  final VaultFileSystem fs;
  final FutureOr<NoteIndex> Function() _getIndex;
  final VaultSettings Function() getSettings;
  final Clock clock;
  final Future<void> Function(VaultPath path) openNote;
  final void Function(String messageKey)? showSnackbar;

  VaultSettings get settings => getSettings();

  /// Creates and opens a unique note.
  Future<VaultPath> create({VaultPath? contextNote}) async {
    final prefixFormat = settings.uniqueNoteSettings.prefixFormat;
    final err = validateMomentFormat(prefixFormat, forFileName: true);
    if (err != null) {
      throw UniqueNoteConfigException(
        'Invalid unique note prefix format: $prefixFormat ($err)',
      );
    }

    final now = clock.now();
    final base = formatMoment(now, prefixFormat);

    VaultPath folder;
    final cfgFolder = settings.uniqueNoteSettings.folder.trim();
    if (cfgFolder.isNotEmpty) {
      folder = VaultPath.tryParse(cfgFolder) ?? VaultPath.root;
    } else {
      folder = resolveNewNoteFolder(settings, contextNote);
    }

    VaultPath makePath(String name) {
      if (folder == VaultPath.root) {
        return VaultPath('$name.md');
      }
      return VaultPath('${folder.value}/$name.md');
    }

    var name = base;
    var path = makePath(name);
    var counter = 2;
    while (await fs.stat(path) != null) {
      name = '$base-$counter';
      path = makePath(name);
      counter++;
    }

    var text = '';
    final t = settings.uniqueNoteSettings.template.trim();
    if (t.isNotEmpty) {
      final candidates = <VaultPath>[];
      final p1 = VaultPath.tryParse(t);
      if (p1 != null) candidates.add(p1);
      if (!t.toLowerCase().endsWith('.md')) {
        final p2 = VaultPath.tryParse('$t.md');
        if (p2 != null) candidates.add(p2);
      }
      final idx = await _getIndex();
      final resolved = await idx.resolveLink(t, from: path);
      if (resolved != null) {
        candidates.add(resolved);
      }

      for (final cand in candidates) {
        final stat = await fs.stat(cand);
        if (stat != null && !stat.isFolder) {
          try {
            final doc = await fs.readText(cand);
            final ctx = TemplateContext(
              title: name,
              date: now,
              now: now,
              dateFormat: settings.templatesDateFormat,
              timeFormat: settings.templatesTimeFormat,
            );
            text = applyTemplate(doc.text, ctx);
            break;
          } catch (_) {
            // Malformed template counts as missing.
          }
        }
      }
    }

    await fs.writeText(path, TextDocument(text: text));
    await openNote(path);
    return path;
  }
}
