// © 2026 Tephra. All rights reserved.

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'note_document.dart';

final _logger = Logger('ConflictResolution');

/// User's resolution choice when resolving a merge conflict.
enum ConflictChoice { keepMine, takeTheirs, keepBoth }

/// Resolves a pending merge conflict on [doc] according to [choice].
Future<void> resolveConflict(
  NoteDocument doc,
  ConflictChoice choice, {
  required VaultFileSystem fs,
  required Clock clock,
}) async {
  final conflict = doc.pendingConflict;
  if (conflict == null) return;

  final theirs = conflict.theirs;
  final theirsHash = conflict.theirsHash;
  final userText = doc.text;

  switch (choice) {
    case ConflictChoice.keepMine:
      doc.applyConflictResolution(
        newSavedText: theirs.text,
        newBase: theirs,
        newDiskHash: theirsHash,
        newText: userText,
        clearHistory: false,
      );
      await doc.save();

    case ConflictChoice.takeTheirs:
      // 1. Write recovery copy of user's version:
      // .tephra/cache/recovery/<yyyyMMddHHmmss>-<file name>
      final now = clock.now().toLocal();
      final stamp = DateFormat('yyyyMMddHHmmss').format(now);
      final fileName = doc.path.name.isNotEmpty ? doc.path.name : 'note.md';
      final recoveryPath = VaultPath('.tephra/cache/recovery/$stamp-$fileName');

      try {
        await fs.writeText(
          recoveryPath,
          TextDocument(
            text: userText,
            hasBom: doc.base.hasBom,
            lineEnding: doc.base.lineEnding,
          ),
        );
      } catch (e) {
        _logger.warning('Failed to write recovery copy to $recoveryPath: $e');
      }

      // 2. Adopt theirs version
      doc.applyConflictResolution(
        newSavedText: theirs.text,
        newBase: theirs,
        newDiskHash: theirsHash,
        newText: theirs.text,
        clearHistory: true,
      );

    case ConflictChoice.keepBoth:
      // 1. Write user version to <stem> (conflict YYYY-MM-DD HH-mm).md in same folder
      final now = clock.now().toLocal();
      final stamp = DateFormat('yyyy-MM-dd HH-mm').format(now);
      final stem = doc.path.stem;
      final parent = doc.path.parent ?? VaultPath.root;

      var conflictFileName = '$stem (conflict $stamp).md';
      var conflictPath = parent.join(conflictFileName);

      var counter = 2;
      while (await fs.stat(conflictPath) != null) {
        conflictFileName = '$stem (conflict $stamp) $counter.md';
        conflictPath = parent.join(conflictFileName);
        counter++;
      }

      await fs.writeText(
        conflictPath,
        TextDocument(
          text: userText,
          hasBom: doc.base.hasBom,
          lineEnding: doc.base.lineEnding,
        ),
      );

      // 2. Behave as takeTheirs without writing recovery copy
      doc.applyConflictResolution(
        newSavedText: theirs.text,
        newBase: theirs,
        newDiskHash: theirsHash,
        newText: theirs.text,
        clearHistory: true,
      );

      doc.onDiskChanged?.call();
  }
}
