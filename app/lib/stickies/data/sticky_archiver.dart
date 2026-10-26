// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../model/sticky.dart';
import '../model/sticky_meta.dart';
import 'sticky_repository.dart';

final _logger = Logger('stickies.archiver');

/// Moves expired sticky notes to `<stickyFolder>/Archive/` automatically.
final class StickyArchiver {
  StickyArchiver({
    required this.repo,
    required this.rename,
    required this.clock,
    required this.stickyFolder,
    VaultFileSystem? fs,
    this.showSnackbar,
  }) : fs = fs ?? repo.fs;

  final StickyRepository repo;
  final Future<void> Function(VaultPath from, VaultPath to) rename;
  final Clock clock;
  final String stickyFolder;
  final VaultFileSystem fs;
  final void Function(int count, VaultPath archiveFolder)? showSnackbar;

  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;
  bool _started = false;

  /// Checks for active stickies whose expiry date has passed, and moves them to `<stickyFolder>/Archive/`.
  Future<List<VaultPath>> archiveExpired() async {
    final now = clock.now();
    final today = LocalDate(now.year, now.month, now.day);
    final archiveFolder = VaultPath(stickyFolder).join('Archive');

    final activeStickies = List<Sticky>.from(repo.all);
    final expired = <Sticky>[];

    for (final s in activeStickies) {
      if (s.path.isWithin(archiveFolder) || s.path == archiveFolder) {
        continue;
      }

      final exp = s.meta.expire;
      if (exp != null && exp.compareTo(today) < 0) {
        expired.add(s);
      }
    }

    if (expired.isEmpty) return const [];

    try {
      if (await fs.stat(archiveFolder) == null) {
        await fs.createFolder(archiveFolder);
      }
    } catch (e, st) {
      _logger.warning('Failed to create archive folder: $archiveFolder', e, st);
    }

    final movedPaths = <VaultPath>[];

    for (final sticky in expired) {
      final stem = sticky.path.stem;
      var targetName = '$stem.md';
      var targetPath = archiveFolder.join(targetName);

      var counter = 1;
      while (await fs.stat(targetPath) != null) {
        targetName = '$stem $counter.md';
        targetPath = archiveFolder.join(targetName);
        counter++;
      }

      try {
        await rename(sticky.path, targetPath);
        movedPaths.add(targetPath);
      } catch (e, st) {
        _logger.warning('Failed to archive sticky ${sticky.path}', e, st);
      }
    }

    if (movedPaths.isNotEmpty) {
      showSnackbar?.call(movedPaths.length, archiveFolder);
    }

    return movedPaths;
  }

  /// Starts scheduled auto-archiving triggers: immediately, on app resume,
  /// and at local midnight + 1 minute every 24 hours.
  void start() {
    if (_started) return;
    _started = true;

    unawaited(archiveExpired());

    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(archiveExpired()),
    );

    _scheduleNextRun();
  }

  void _scheduleNextRun() {
    _timer?.cancel();
    final now = clock.now();
    final nextRun = DateTime(now.year, now.month, now.day + 1, 0, 1);
    final delay = nextRun.difference(now);

    _timer = Timer(delay, () async {
      await archiveExpired();
      _timer = Timer.periodic(const Duration(hours: 24), (_) {
        unawaited(archiveExpired());
      });
    });
  }

  void dispose() {
    _timer?.cancel();
    _lifecycleListener?.dispose();
    _started = false;
  }
}
