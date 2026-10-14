// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

import '../l10n/app_localizations.dart';
import 'attachment_service.dart';
import 'edit_operation.dart';
import 'editor_controller.dart';
import 'providers.dart';

/// Representation of an incoming attachment to insert into a note.
final class AttachmentInput {
  const AttachmentInput({
    required this.bytes,
    required this.fileName,
    this.isImage = false,
  });

  final List<int> bytes;
  final String fileName;
  final bool isImage;
}

/// Abstract interface for clipboard file and image querying to allow testing.
abstract interface class ClipboardImageSource {
  Future<List<String>> files();
  Future<Uint8List?> image();
}

/// Production implementation of [ClipboardImageSource] using [Pasteboard].
final class SystemClipboardImageSource implements ClipboardImageSource {
  const SystemClipboardImageSource();

  @override
  Future<List<String>> files() => Pasteboard.files();

  @override
  Future<Uint8List?> image() => Pasteboard.image;
}

/// Saves and inserts one or more attachments at the editor's caret position.
Future<void> insertAttachmentsInto(
  EditorController c,
  WidgetRef ref,
  List<AttachmentInput> inputs, {
  BuildContext? context,
}) async {
  if (inputs.isEmpty) return;
  final service = ref.read(attachmentServiceProvider);
  final note = c.document.path;

  final embeds = <String>[];
  var hadTooLarge = false;
  var hadFailed = false;

  for (final input in inputs) {
    try {
      final VaultPath saved;
      if (input.isImage) {
        if (input.fileName.isNotEmpty && input.bytes.isNotEmpty) {
          saved = await service.save(
            note: note,
            bytes: input.bytes,
            fileName: input.fileName,
          );
        } else {
          saved = await service.savePastedImage(note: note, bytes: input.bytes);
        }
      } else {
        saved = await service.save(
          note: note,
          bytes: input.bytes,
          fileName: input.fileName,
        );
      }
      final embedText = await service.embedTextFor(saved);
      embeds.add(embedText);
    } on AttachmentTooLargeException {
      hadTooLarge = true;
    } catch (_) {
      hadFailed = true;
    }
  }

  if (embeds.isNotEmpty) {
    final textToInsert = embeds.join('\n');
    final sel = c.selection;
    final selStart = sel.start;
    final selEnd = sel.end;
    c.apply(EditOperation(selStart, selEnd, textToInsert), selectAfter: true);
  }

  if (context != null && context.mounted) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (hadTooLarge) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentTooLarge)));
    } else if (hadFailed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentFailed)));
    }
  }
}

/// Handles clipboard paste of images or files on Windows.
Future<bool> handlePasteAttachment(
  EditorController c,
  WidgetRef ref, {
  BuildContext? context,
  ClipboardImageSource? clipboard,
  bool? isWindowsOverride,
}) async {
  final isWindows = isWindowsOverride ?? (!kIsWeb && Platform.isWindows);
  if (!isWindows) return false;

  final source = clipboard ?? const SystemClipboardImageSource();
  final files = await source.files();
  if (files.isNotEmpty) {
    final inputs = <AttachmentInput>[];
    for (final filePath in files) {
      try {
        final bytes = File(filePath).readAsBytesSync();
        final name = p.basename(filePath);
        final ext = p.extension(filePath).toLowerCase();
        final isImg = const [
          '.png',
          '.jpg',
          '.jpeg',
          '.gif',
          '.webp',
          '.bmp',
        ].contains(ext);
        inputs.add(
          AttachmentInput(bytes: bytes, fileName: name, isImage: isImg),
        );
      } catch (_) {
        // Skip unreadable files
      }
    }
    if (inputs.isNotEmpty) {
      if (context != null && !context.mounted) return true;
      await insertAttachmentsInto(c, ref, inputs, context: context);
      return true;
    }
    return false;
  }

  final imgBytes = await source.image();
  if (imgBytes != null && imgBytes.isNotEmpty) {
    final input = AttachmentInput(bytes: imgBytes, fileName: '', isImage: true);
    if (context != null && !context.mounted) return true;
    await insertAttachmentsInto(c, ref, [input], context: context);
    return true;
  }

  return false;
}

/// Prompts user to pick files/photos and inserts them as attachments.
Future<void> pickAndInsertAttachment(
  BuildContext context,
  WidgetRef ref, {
  bool? isAndroidOverride,
  ImagePicker? imagePicker,
  Future<List<PlatformFile>> Function()? pickFiles,
}) async {
  final c = ref.read(activeEditorProvider);
  if (c == null) return;

  final isAndroid = isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);
  final picker = imagePicker ?? ImagePicker();
  final pickerFunc = pickFiles ?? FilePicker.pickFiles;

  if (isAndroid) {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.attachmentPickPhoto),
                  onTap: () => Navigator.of(sheetContext).pop('photo'),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(l10n.attachmentTakePhoto),
                  onTap: () => Navigator.of(sheetContext).pop('camera'),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(l10n.attachmentPickFile),
                  onTap: () => Navigator.of(sheetContext).pop('file'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'photo') {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!context.mounted) return;
        await insertAttachmentsInto(c, ref, [
          AttachmentInput(bytes: bytes, fileName: '', isImage: true),
        ], context: context);
      }
    } else if (choice == 'camera') {
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!context.mounted) return;
        await insertAttachmentsInto(c, ref, [
          AttachmentInput(bytes: bytes, fileName: '', isImage: true),
        ], context: context);
      }
    } else if (choice == 'file') {
      final pickedFiles = await pickerFunc();
      if (pickedFiles.isNotEmpty) {
        final inputs = <AttachmentInput>[];
        for (final f in pickedFiles) {
          try {
            final bytes = await f.readAsBytes();
            final ext = p.extension(f.name).toLowerCase();
            final isImg = const [
              '.png',
              '.jpg',
              '.jpeg',
              '.gif',
              '.webp',
              '.bmp',
            ].contains(ext);
            inputs.add(
              AttachmentInput(bytes: bytes, fileName: f.name, isImage: isImg),
            );
          } catch (_) {
            // Ignore unreadable file
          }
        }
        if (!context.mounted) return;
        await insertAttachmentsInto(c, ref, inputs, context: context);
      }
    }
  } else {
    // Windows & other desktop platforms
    final pickedFiles = await pickerFunc();
    if (pickedFiles.isNotEmpty) {
      final inputs = <AttachmentInput>[];
      for (final f in pickedFiles) {
        try {
          final bytes = await f.readAsBytes();
          final ext = p.extension(f.name).toLowerCase();
          final isImg = const [
            '.png',
            '.jpg',
            '.jpeg',
            '.gif',
            '.webp',
            '.bmp',
          ].contains(ext);
          inputs.add(
            AttachmentInput(bytes: bytes, fileName: f.name, isImage: isImg),
          );
        } catch (_) {
          // Ignore unreadable file
        }
      }
      if (!context.mounted) return;
      await insertAttachmentsInto(c, ref, inputs, context: context);
    }
  }
}
