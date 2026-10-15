// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../settings/vault_settings.dart';
import 'exceptions.dart';

/// Service providing Obsidian-compatible daily note operations.
final class DailyNotesService {
  DailyNotesService({
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
  final Future<void> Function(VaultPath path, {bool newTab}) openNote;
  final void Function(String messageKey)? showSnackbar;

  VaultSettings get settings => getSettings();

  /// Computes the [VaultPath] for a daily note on [date].
  VaultPath pathFor(DateTime date) {
    final format = settings.dailyNotesSettings.format;
    final folder = settings.dailyNotesSettings.folder;
    return dailyNotePath(date, folder: folder, format: format);
  }

  /// Extracts the date from [p] if it is inside the daily notes folder and matches format.
  DateTime? dateOfPath(VaultPath p) {
    final format = settings.dailyNotesSettings.format;
    final folder = settings.dailyNotesSettings.folder;

    String rel;
    if (folder.isNotEmpty) {
      if (folder == '/') {
        rel = p.value;
      } else {
        final prefix = '$folder/';
        if (!p.value.startsWith(prefix)) return null;
        rel = p.value.substring(prefix.length);
      }
    } else {
      rel = p.value;
    }

    if (!rel.toLowerCase().endsWith('.md')) return null;
    rel = rel.substring(0, rel.length - 3);

    return parseMoment(rel, format);
  }

  /// Opens or creates the daily note for [date].
  Future<VaultPath> openOrCreate(DateTime date, {bool newTab = false}) async {
    final format = settings.dailyNotesSettings.format;
    final err = validateMomentFormat(
      format,
      forFileName: true,
      requireDate: true,
    );
    if (err != null) {
      throw DailyNotesConfigException('Invalid daily note format: $format');
    }

    final path = pathFor(date);

    // If file already exists, open it without writing.
    final existingStat = await fs.stat(path);
    if (existingStat != null) {
      await openNote(path, newTab: newTab);
      return path;
    }

    // Build content from template if configured.
    var text = '';
    final t = settings.dailyNotesSettings.template.trim();
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

      var found = false;
      for (final cand in candidates) {
        final stat = await fs.stat(cand);
        if (stat != null && !stat.isFolder) {
          try {
            final doc = await fs.readText(cand);
            final ctx = TemplateContext(
              title: path.stem,
              date: date,
              now: clock.now(),
              dateFormat: settings.templatesDateFormat,
              timeFormat: settings.templatesTimeFormat,
            );
            text = applyTemplate(doc.text, ctx);
            found = true;
            break;
          } catch (_) {
            // Malformed template counts as missing.
          }
        }
      }

      if (!found) {
        text = '';
        showSnackbar?.call('dailyTemplateMissing');
      }
    }

    // Re-stat immediately before writing to avoid race conditions.
    if (await fs.stat(path) != null) {
      await openNote(path, newTab: newTab);
      return path;
    }

    await fs.writeText(path, TextDocument(text: text));
    await openNote(path, newTab: newTab);
    return path;
  }

  /// Finds the previous or next daily note relative to [from] (or today if null).
  Future<VaultPath?> neighbour(
    VaultPath? from, {
    required bool previous,
  }) async {
    final today = clock.now();
    final current = from == null ? today : (dateOfPath(from) ?? today);
    final currentDate = DateTime(current.year, current.month, current.day);

    final idx = await _getIndex();
    final all = await idx.allFiles();
    final candidates = <({VaultPath path, DateTime date})>[];
    for (final record in all) {
      final file = record.path;
      final d = dateOfPath(file);
      if (d != null) {
        candidates.add((path: file, date: DateTime(d.year, d.month, d.day)));
      }
    }

    if (previous) {
      final prevs = candidates
          .where((c) => c.date.isBefore(currentDate))
          .toList();
      if (prevs.isEmpty) return null;
      prevs.sort((a, b) => b.date.compareTo(a.date));
      return prevs.first.path;
    } else {
      final nexts = candidates
          .where((c) => c.date.isAfter(currentDate))
          .toList();
      if (nexts.isEmpty) return null;
      nexts.sort((a, b) => a.date.compareTo(b.date));
      return nexts.first.path;
    }
  }
}
