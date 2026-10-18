// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../core/providers.dart';
import '../../explorer/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/providers.dart';
import '../providers.dart';
import 'daily_notes_service.dart';
import 'template_service.dart';
import 'unique_note_service.dart';

/// Provides [DailyNotesService].
final dailyNotesServiceProvider = Provider<DailyNotesService>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final clock = ref.watch(clockProvider);
  return DailyNotesService(
    fs: fs,
    index: () => ref.read(noteIndexProvider.future),
    getSettings: () => ref.read(vaultSettingsProvider),
    clock: clock,
    openNote: (path, {newTab = false}) async {
      ref.read(workspaceProvider.notifier).openPath(path, newTab: newTab);
    },
    showSnackbar: (key) {
      final smKey = ref.read(scaffoldMessengerKeyProvider);
      final context = smKey.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        String msg = key;
        if (key == 'dailyTemplateMissing') {
          msg = l10n.dailyTemplateMissing;
        } else if (key == 'dailyFormatInvalid') {
          msg = l10n.dailyFormatInvalid;
        } else if (key == 'dailyNoNeighbour') {
          msg = l10n.dailyNoNeighbour;
        }
        smKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
      }
    },
  );
});

/// Provides [TemplateService].
final templateServiceProvider = Provider<TemplateService>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final clock = ref.watch(clockProvider);
  return TemplateService(
    fs: fs,
    index: () => ref.read(noteIndexProvider.future),
    getSettings: () => ref.read(vaultSettingsProvider),
    clock: clock,
    showSnackbar: (key) {
      final smKey = ref.read(scaffoldMessengerKeyProvider);
      final context = smKey.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        String msg = key;
        if (key == 'templatesFolderNotSet') {
          msg = l10n.templatesFolderNotSet;
        } else if (key == 'templateUnreadable') {
          msg = l10n.templateUnreadable;
        }
        smKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
      }
    },
  );
});

/// Provides [UniqueNoteService].
final uniqueNoteServiceProvider = Provider<UniqueNoteService>((ref) {
  final fs = ref.watch(vaultFsProvider);
  final clock = ref.watch(clockProvider);
  return UniqueNoteService(
    fs: fs,
    index: () => ref.read(noteIndexProvider.future),
    getSettings: () => ref.read(vaultSettingsProvider),
    clock: clock,
    openNote: (path) async {
      ref.read(workspaceProvider.notifier).openPath(path);
    },
  );
});

/// Runner for opening the daily note on vault startup if configured.
final class DailyStartupRunner {
  DailyStartupRunner(this.ref);
  final Ref ref;
  bool _hasRun = false;

  Future<void> run() async {
    if (_hasRun) return;
    _hasRun = true;
    final settings = ref.read(vaultSettingsProvider);
    if (settings.corePluginsSettings.dailyNotes &&
        settings.dailyNotesSettings.openOnStartup) {
      final clock = ref.read(clockProvider);
      final today = clock.now();
      try {
        await ref.read(dailyNotesServiceProvider).openOrCreate(today);
      } catch (_) {}
    }
  }
}

/// Provides [DailyStartupRunner] which runs once per vault session.
final dailyStartupProvider = Provider<DailyStartupRunner>((ref) {
  return DailyStartupRunner(ref);
});

/// Cached list of daily notes in the vault, sorted by date.
final dailyNoteListProvider =
    FutureProvider<List<({VaultPath path, DateTime date})>>((ref) async {
      ref.watch(indexChangesProvider);
      final index = await ref.watch(noteIndexProvider.future);
      final dailyService = ref.watch(dailyNotesServiceProvider);
      final all = await index.allFiles();
      final list = <({VaultPath path, DateTime date})>[];
      for (final file in all) {
        final d = dailyService.dateOfPath(file.path);
        if (d != null) {
          list.add((path: file.path, date: DateTime(d.year, d.month, d.day)));
        }
      }
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
