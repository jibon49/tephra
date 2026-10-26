// © 2026 Tephra. All rights reserved.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/headless_config.dart';
import '../core/platform/notification_service.dart';
import '../stickies/data/sticky_file_writer.dart';

final _logger = Logger('quick_note.reply');

/// Top-level background notification response handler for quick replies.
@pragma('vm:entry-point')
void quickNoteReplyHandler(NotificationResponse r) async {
  if (r.actionId != 'quick_note_reply') return;
  final input = r.input?.trim();
  if (input == null || input.isEmpty) return;

  DartPluginRegistrant.ensureInitialized();

  try {
    final dir = await getApplicationSupportDirectory();
    final configFile = File(p.join(dir.path, HeadlessConfig.defaultFileName));
    final cfg = await HeadlessConfig.load(configFile);
    if (cfg == null) {
      _logger.warning('Cannot handle quick reply: headless config not found');
      return;
    }
    if (cfg.fsKind != 'io') {
      _logger.info('Quick reply ignored: fsKind is ${cfg.fsKind}');
      return;
    }

    final fs = IoVaultFileSystem(cfg.vaultRoot);
    await appendQuickNote(fs, cfg, input, DateTime.now());

    // Re-show notification so user can reply again
    final notif = AndroidNotificationService();
    await notif.showQuickNoteNotification();
  } catch (e, st) {
    _logger.warning('Failed to handle quick note reply', e, st);
  }
}

/// Appends [text] to the appropriate quick-note target (daily note or inbox).
///
/// Returns the [VaultPath] written to, or null if [cfg.fsKind] is not 'io'.
Future<VaultPath?> appendQuickNote(
  VaultFileSystem fs,
  HeadlessConfig cfg,
  String text,
  DateTime now,
) async {
  if (cfg.fsKind != 'io') {
    return null;
  }

  final VaultPath targetPath;
  if (cfg.quickTarget == 'inbox') {
    targetPath = VaultPath(cfg.inboxPath);
  } else {
    targetPath = dailyNotePath(
      now,
      folder: cfg.dailyNote.folder,
      format: cfg.dailyNote.format,
    );
  }

  if (targetPath.parent != null && !targetPath.parent!.isRoot) {
    try {
      await fs.createFolder(targetPath.parent!);
    } catch (_) {}
  }

  final timeStr = DateFormat('HH:mm').format(now.toLocal());
  final textLines = text.split('\n');
  final lines = <String>[];
  lines.add('- $timeStr ${textLines.first}');
  for (var i = 1; i < textLines.length; i++) {
    lines.add('  ${textLines[i]}');
  }
  final block = '${lines.join('\n')}\n';

  final writer = StickyFileWriter(fs);
  await writer.append(targetPath, block);
  return targetPath;
}
