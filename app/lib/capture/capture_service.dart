// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../core/platform/share_intent_service.dart';
import '../editor/attachment_paths.dart';
import '../editor/attachment_service.dart';
import '../editor/image_type.dart';
import '../settings/vault_settings.dart';
import '../vault/note_tools/daily_notes_service.dart';
import 'share_intake.dart';

/// Service responsible for saving captured text and attachments to the vault as a new note,
/// or appending to today's daily note or the inbox note.
final class CaptureService {
  CaptureService({
    required this.fs,
    required this.dailyNotesService,
    required this.attachmentService,
    required this.getVaultSettings,
    required this.clock,
  });

  final VaultFileSystem fs;
  final DailyNotesService dailyNotesService;
  final AttachmentService attachmentService;
  final VaultSettings Function() getVaultSettings;
  final Clock clock;

  /// Saves [d] as a new note in the configured new-note folder, ensuring a unique file name.
  Future<VaultPath> saveAsNewNote(CaptureDraft d) async {
    final vs = getVaultSettings();
    final folder =
        vs.newFileLocationEnum == NewFileLocation.folder &&
            vs.newFileFolder.isNotEmpty
        ? VaultPath(vs.newFileFolder)
        : VaultPath.root;

    if (!folder.isRoot) {
      await fs.createFolder(folder);
    }

    final rawTitle = d.title?.trim() ?? 'Untitled';
    final stem = rawTitle.isEmpty ? 'Untitled' : rawTitle;

    var targetName = '$stem.md';
    var targetPath = folder.isRoot
        ? VaultPath(targetName)
        : folder.join(targetName);

    var counter = 1;
    while (await fs.stat(targetPath) != null) {
      targetName = '$stem $counter.md';
      targetPath = folder.isRoot
          ? VaultPath(targetName)
          : folder.join(targetName);
      counter++;
    }

    final embeds = await _saveAttachments(targetPath, d.files);

    final String content;
    final text = d.text.trim();
    if (text.isNotEmpty && embeds.isNotEmpty) {
      content = '$text\n\n${embeds.join('\n')}\n';
    } else if (text.isNotEmpty) {
      content = '$text\n';
    } else if (embeds.isNotEmpty) {
      content = '${embeds.join('\n')}\n';
    } else {
      content = '';
    }

    await fs.writeText(targetPath, TextDocument(text: content));
    return targetPath;
  }

  /// Appends [d] to today's daily note, creating the note from template if missing.
  Future<VaultPath> appendToDailyNote(CaptureDraft d) async {
    final notePath = await dailyNotesService.openOrCreate(clock.now());
    final embeds = await _saveAttachments(notePath, d.files);

    final currentBytes = await fs.readBytes(notePath);
    final doc = TextDocument.decode(currentBytes);
    final current = doc.text;

    final block = _formatAppendBlock(d, embeds);
    final String updated;
    if (current.isEmpty) {
      updated = block.startsWith('\n') ? block.substring(1) : block;
    } else if (current.endsWith('\n')) {
      updated =
          '$current${block.startsWith('\n') ? block.substring(1) : block}';
    } else {
      updated = '$current$block';
    }

    await fs.writeText(notePath, doc.copyWith(text: updated));
    return notePath;
  }

  /// Appends [d] to the configured inbox note (`settings.inboxNotePath`), creating it if missing.
  Future<VaultPath> appendToInbox(CaptureDraft d) async {
    final vs = getVaultSettings();
    final inboxPath = VaultPath(vs.inboxNotePath);

    if (inboxPath.parent != null && !inboxPath.parent!.isRoot) {
      await fs.createFolder(inboxPath.parent!);
    }

    final stat = await fs.stat(inboxPath);
    final embeds = await _saveAttachments(inboxPath, d.files);
    final block = _formatAppendBlock(d, embeds);

    if (stat == null) {
      final initial = block.startsWith('\n') ? block.substring(1) : block;
      await fs.writeText(inboxPath, TextDocument(text: initial));
      return inboxPath;
    }

    final bytes = await fs.readBytes(inboxPath);
    final doc = TextDocument.decode(bytes);
    final current = doc.text;

    final String updated;
    if (current.isEmpty) {
      updated = block.startsWith('\n') ? block.substring(1) : block;
    } else if (current.endsWith('\n')) {
      updated =
          '$current${block.startsWith('\n') ? block.substring(1) : block}';
    } else {
      updated = '$current$block';
    }

    await fs.writeText(inboxPath, doc.copyWith(text: updated));
    return inboxPath;
  }

  Future<List<String>> _saveAttachments(
    VaultPath targetNote,
    List<SharedFile> files,
  ) async {
    final embeds = <String>[];
    for (final file in files) {
      final List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        final f = File(file.path);
        if (f.existsSync()) {
          bytes = await f.readAsBytes();
        } else {
          continue;
        }
      }

      final isImage =
          file.mimeType?.startsWith('image/') ??
          [
            '.png',
            '.jpg',
            '.jpeg',
            '.gif',
            '.webp',
            '.bmp',
          ].any((ext) => file.path.toLowerCase().endsWith(ext));

      final String fileName;
      if (isImage) {
        final ext = detectImageExtension(bytes) ?? 'png';
        fileName = pastedImageName(clock.now().toLocal(), ext);
      } else {
        fileName = p.basename(file.path);
      }

      final saved = await attachmentService.save(
        note: targetNote,
        bytes: bytes,
        fileName: fileName,
      );
      final embed = await attachmentService.embedTextFor(saved);
      embeds.add(embed);
    }
    return embeds;
  }

  String _formatAppendBlock(CaptureDraft d, List<String> embeds) {
    final timeStr = DateFormat('HH:mm').format(clock.now().toLocal());
    final lines = <String>[];

    final trimmed = d.text.trim();
    if (trimmed.isNotEmpty) {
      final textLines = trimmed.split('\n');
      lines.add('- $timeStr ${textLines.first}');
      for (var i = 1; i < textLines.length; i++) {
        lines.add('  ${textLines[i]}');
      }
      for (final embed in embeds) {
        lines.add('  $embed');
      }
    } else {
      lines.add('- $timeStr');
      for (final embed in embeds) {
        lines.add('  $embed');
      }
    }

    return '\n${lines.join('\n')}\n';
  }
}
