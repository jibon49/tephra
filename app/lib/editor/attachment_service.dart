// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../core/providers.dart';
import '../vault/providers.dart';
import 'attachment_paths.dart';
import 'image_type.dart';

/// Exception thrown when an attachment exceeds [AttachmentService.maxBytes].
final class AttachmentTooLargeException extends TephraException {
  const AttachmentTooLargeException([String? message])
    : super(message ?? 'Attachment exceeds maximum allowed size (200 MB)');
}

final class AttachmentService {
  AttachmentService(this.ref);

  final Ref ref;

  static const int maxBytes = 200 * 1024 * 1024; // 200 MB

  /// Saves [bytes] next to/under the folder chosen by settings and returns the saved path.
  /// Never overwrites: a taken name gets " 1", " 2", … before the extension.
  Future<VaultPath> save({
    required VaultPath note,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.length > maxBytes) {
      throw const AttachmentTooLargeException();
    }

    final session = ref.read(vaultSessionProvider);
    if (session == null) {
      throw StateError('No active vault session');
    }
    final fs = session.fs;
    final setting = ref.read(vaultSettingsProvider).attachmentFolder;
    final folder = attachmentFolderFor(note, setting);

    if (!folder.isRoot) {
      await fs.createFolder(folder);
    }

    final sanitized = sanitizeAttachmentName(fileName);
    final dotIdx = sanitized.lastIndexOf('.');
    final stem = dotIdx == -1 ? sanitized : sanitized.substring(0, dotIdx);
    final ext = dotIdx == -1 ? '' : sanitized.substring(dotIdx);

    var targetName = sanitized;
    var targetPath = folder.isRoot
        ? VaultPath(targetName)
        : folder.join(targetName);

    var counter = 1;
    while (await fs.stat(targetPath) != null) {
      targetName = '$stem $counter$ext';
      targetPath = folder.isRoot
          ? VaultPath(targetName)
          : folder.join(targetName);
      counter++;
    }

    await fs.writeBytes(targetPath, bytes);
    ref.read(vaultRevisionProvider.notifier).bump();
    return targetPath;
  }

  /// Saves image bytes as a pasted image attachment with automatic format detection.
  Future<VaultPath> savePastedImage({
    required VaultPath note,
    required List<int> bytes,
  }) async {
    final ext = detectImageExtension(bytes) ?? 'png';
    final clock = ref.read(clockProvider);
    final fileName = pastedImageName(clock.now().toLocal(), ext);
    return save(note: note, bytes: bytes, fileName: fileName);
  }

  /// The markdown embed text for [saved]: `![[name.ext]]`, or `![[folder/name.ext]]`
  /// when another file with the same name exists elsewhere in the vault.
  Future<String> embedTextFor(VaultPath saved) async {
    final session = ref.read(vaultSessionProvider);
    if (session == null) {
      return '![[${saved.name}]]';
    }
    final fs = session.fs;
    final allEntries = await fs.list(recursive: true);
    final sameNameCount = allEntries
        .where((e) => !e.isFolder && e.path.name == saved.name)
        .length;

    if (sameNameCount > 1) {
      return '![[${saved.value}]]';
    }
    return '![[${saved.name}]]';
  }
}
