// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

/// Atomic file writer for headless background stickies operations.
final class StickyFileWriter {
  StickyFileWriter(this.fs);

  final VaultFileSystem fs;

  /// Writes [newText] only if the file's current contentHash equals [expectedHash].
  ///
  /// Returns the new hash, or null if the file changed meanwhile (nothing written).
  /// Preserves BOM and line ending of the current file.
  Future<String?> writeIfUnchanged(
    VaultPath path,
    String expectedHash,
    String newText,
  ) async {
    final List<int> bytes;
    try {
      bytes = await fs.readBytes(path);
    } on FileNotFoundException {
      return null;
    }

    final currentHash = contentHash(bytes);
    if (currentHash != expectedHash) {
      return null;
    }

    final doc = TextDocument.decode(bytes);
    final updatedDoc = doc.copyWith(text: newText);
    await fs.writeText(path, updatedDoc);
    return contentHash(updatedDoc.encode());
  }

  /// Appends [block] to the end of the note (adds '\n' first if the note does not end with '\n');
  /// creates the note if missing.
  Future<void> append(VaultPath path, String block) async {
    try {
      final bytes = await fs.readBytes(path);
      final doc = TextDocument.decode(bytes);
      final current = doc.text;
      final toAppend = (current.isNotEmpty && !current.endsWith('\n'))
          ? '\n$block'
          : block;
      final updatedDoc = doc.copyWith(text: '$current$toAppend');
      await fs.writeText(path, updatedDoc);
    } on FileNotFoundException {
      final newDoc = TextDocument(text: block);
      await fs.writeText(path, newDoc);
    }
  }
}
